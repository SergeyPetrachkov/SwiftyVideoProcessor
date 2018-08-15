//
//  VideoProcessor.swift
//  PreUploadVideoProcessor
//
//  Created by Sergey Petrachkov on 14/08/2018.
//  Copyright © 2018 Sergey Petrachkov. All rights reserved.
//

import Foundation
import AVFoundation
enum AssetExportSessionError: Error {
  case nilWriter
  case nilReader
  case sessionError(details: String)
}
protocol AssetExportSessionDelegate: NSObjectProtocol {
  func exportSession(_ exportSession: AssetExportSession?, renderFrame pixelBuffer: CVPixelBuffer?, withPresentationTime presentationTime: CMTime, to renderBuffer: CVPixelBuffer?)
}
//
class AssetExportSession: NSObject {
  
  weak var delegate: AssetExportSessionDelegate?
  
  private(set) var asset: AVAsset!
  
  var videoComposition: AVVideoComposition?
  var audioMix: AVAudioMix?
  var outputFileType: AVFileType = .mp4
  var outputURL: URL
  var videoInputSettings: [String : Any] = [:]
  var videoSettings: [String : Any] = [:]
  var audioSettings: [String : Any] = [:]
  var timeRange: CMTimeRange
  var shouldOptimizeForNetworkUse = false
  var metadata: [AVMetadataItem] = []
  
  private(set) var error: Error?
  private(set) var progress: Double = 0.0
  private(set) var status: AVAssetExportSessionStatus?
  
  private var reader: AVAssetReader!
  private var writer: AVAssetWriter!
  
  private var videoInput: AVAssetWriterInput!
  private var videoOutput: AVAssetReaderVideoCompositionOutput!
  
  private var audioOutput: AVAssetReaderAudioMixOutput!
  private var audioInput: AVAssetWriterInput!
  
  
  private var videoPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
  
  private var inputQueue: DispatchQueue = DispatchQueue(label: "SwiftyExportSessionQueue")
  
  var completionHandler: (() -> Void)?
  
  private var duration: TimeInterval = 0.0
  private var lastSamplePresentationTime: CMTime!
  
  init(asset: AVAsset, outputUrl: URL, outputFileType: AVFileType, videoSettings: [String: Any], audioSettings: [String: Any]) {
    self.asset = asset
    self.outputURL = outputUrl
    self.outputFileType = outputFileType
    self.videoSettings = videoSettings
    self.audioSettings = audioSettings
    
    self.timeRange = CMTimeRange(start: kCMTimeZero, duration: kCMTimePositiveInfinity)
  }

  
  func exportAsynchronously(completionHandler handler: @escaping () -> Void) throws {
//    self.cancelExport()
    self.completionHandler = handler
    do {
      self.reader = try AVAssetReader(asset: self.asset)
    } catch let error {
      throw error
    }

    do {
      self.writer = try AVAssetWriter(url: self.outputURL, fileType: self.outputFileType)
    } catch let error {
      throw error
    }
    self.reader.timeRange = self.timeRange
    self.writer.shouldOptimizeForNetworkUse = self.shouldOptimizeForNetworkUse
    self.writer.metadata = self.metadata
    
    let videoTracks = self.asset.tracks(withMediaType: .video)
    if timeRange.duration.isValid && !timeRange.duration.isPositiveInfinity {
      self.duration = timeRange.duration.seconds
    } else {
      self.duration = self.asset.duration.seconds
    }
    
    if videoTracks.count > 0 {
      self.videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: nil)
      self.videoOutput.alwaysCopiesSampleData = false
      if self.videoComposition != nil {
        self.videoOutput.videoComposition = videoComposition
      } else {
        self.videoOutput.videoComposition = self.buildDefaultVideoComposition()
      }
      
      if self.reader.canAdd(self.videoOutput) {
        self.reader.add(self.videoOutput)
      }
      
      self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: self.videoSettings)
      self.videoInput?.expectsMediaDataInRealTime = true
      if self.writer.canAdd(videoInput) {
        self.writer.add(self.videoInput)
      }

      let pixelBufferAttributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                                  kCVPixelBufferWidthKey as String: self.videoOutput.videoComposition?.renderSize.width ?? 0,
                                                  kCVPixelBufferHeightKey as String: self.videoOutput.videoComposition?.renderSize.height ?? 0,
                                                  "IOSurfaceOpenGLESTextureCompatibility": true,
                                                  "IOSurfaceOpenGLESFBOCompatibility": true]
      
      self.videoPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.videoInput, sourcePixelBufferAttributes: pixelBufferAttributes)
    }
    
//    //
//    //Audio output
//    //
//
//    let audioTracks = self.asset.tracks(withMediaType: .audio)
//    if audioTracks.count > 0 {
//      self.audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
//      self.audioOutput.alwaysCopiesSampleData = false
//      self.audioOutput.audioMix = self.audioMix
//      if self.reader.canAdd(self.audioOutput) {
//        self.reader.add(self.audioOutput)
//      }
//    } else {
//      // Just in case this gets reused
//      audioOutput = nil
//    }
//    //
//    // Audio input
//    //
//    if audioOutput != nil {
//      self.audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
//      self.audioInput.expectsMediaDataInRealTime = true
//      if self.writer.canAdd(self.audioInput) {
//        self.writer.add(self.audioInput)
//      }
//    }
    self.writer.startWriting()
    self.reader.startReading()
    self.writer.startSession(atSourceTime: self.timeRange.start)
    
    
    if videoTracks.count > 0 {
      let videoGroup = DispatchGroup()
      videoGroup.enter()
      self.videoInput.requestMediaDataWhenReady(on: self.inputQueue, using: { [weak self] in
        do {
          try self?.encodeReadySamples(from: (self?.videoOutput)!, to: (self?.videoInput)!)
          videoGroup.leave()
        } catch let error {
          print(error)
          videoGroup.leave()
        }
      })
      _ = videoGroup.wait(timeout: .distantFuture)
      try? self.finish()
//      if self.audioOutput == nil {
//        try? self.finish()
//      } else {
//        self.audioInput.requestMediaDataWhenReady(on: inputQueue, using: { [weak self] in
//          do {
//            try self?.encodeReadySamples(from: (self?.audioOutput)!, to: (self?.audioInput)!)
//            
//            do {
//              try self?.finish()
//            } catch let error {
//              print(error)
//            }
//          } catch let error {
//            print (error)
//          }
//        })
//      }
    }
  }
  
  func buildDefaultVideoComposition() -> AVMutableVideoComposition? {
    guard let videoTrack = self.asset.tracks(withMediaType: .video).first else {
      return nil
    }
    
    let videoComposition = AVMutableVideoComposition(propertiesOf: self.asset)
    
    // get the frame rate from videoSettings, if not set then try to get it from the video track,
    // if not set (mainly when asset is AVComposition) then use the default frame rate of 30
    var trackFrameRate: Float = 0
    
    if let compressionProperties = self.videoSettings[AVVideoCompressionPropertiesKey] as? [String: Any],
      let frameRate = compressionProperties[AVVideoAverageNonDroppableFrameRateKey] as? Float {
      trackFrameRate = frameRate
    } else {
      trackFrameRate = videoTrack.nominalFrameRate
    }
    
    if trackFrameRate == 0 {
      trackFrameRate = 30
    }
    

    videoComposition.frameDuration = CMTimeMake(1, Int32.init(trackFrameRate))
    
    let width: Double = (self.videoSettings[AVVideoWidthKey] as? NSNumber)?.doubleValue ?? 0
    let height: Double = (self.videoSettings[AVVideoHeightKey] as? NSNumber)?.doubleValue ?? 0
    
    let targetSize = CGSize(width: width, height: height)
    
    var naturalSize: CGSize = videoTrack.naturalSize
    var transform: CGAffineTransform = videoTrack.preferredTransform
//    let rect = CGRect(origin: .zero, size: naturalSize)
//
//    let transformedRect = rect.applying(transform);
//    // transformedRect should have origin at 0 if correct; otherwise add offset to correct it
//    transform.tx -= transformedRect.origin.x;
//    transform.ty -= transformedRect.origin.y;
    
    // Workaround radar 31928389, see https://github.com/rs/SDAVAssetExportSession/pull/70 for more info
    if transform.ty == -560 {
      transform.ty = 0
    }
    if transform.tx == -560 {
      transform.tx = 0
    }
    
    let videoAngleInDegree: CGFloat = atan2(transform.b, transform.a) * 180 / .pi
    if videoAngleInDegree == 90 || videoAngleInDegree == -90 {
      let width: CGFloat? = naturalSize.width
      naturalSize.width = naturalSize.height
      naturalSize.height = width ?? 0.0
    }
    videoComposition.renderSize = naturalSize
    
//    // center inside
//    let ratio: CGFloat = 0.0
//    let xratio: CGFloat = targetSize.width / naturalSize.width
//    let yratio: CGFloat = targetSize.height / naturalSize.height
//    let postWidth: CGFloat = naturalSize.width * ratio
//    let postHeight: CGFloat = naturalSize.height * ratio
//    let transx: CGFloat = (targetSize.width - postWidth) / 2
//    let transy: CGFloat = (targetSize.height - postHeight) / 2
//    let matrix = CGAffineTransform(translationX: transx / xratio, y: transy / yratio)
//    transform = transform.concatenating(matrix)
    

    // Make a "pass through video track" video composition.
    
    
    let passThroughInstruction = AVMutableVideoCompositionInstruction()
    passThroughInstruction.timeRange = CMTimeRange(start: kCMTimeZero, duration: self.asset.duration)
    let passThroughLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    passThroughLayer.setTransform(transform, at: kCMTimeZero)
    passThroughInstruction.layerInstructions = [passThroughLayer]
    videoComposition.instructions = [passThroughInstruction]
    return videoComposition
  }
  
  
  func cancelExport() {
    self.inputQueue.async(execute: {
      self.writer?.cancelWriting()
      self.reader?.cancelReading()
      try? self.complete()
      self.reset()
    })
  }
  
  func encodeReadySamples(from output: AVAssetReaderOutput, to input: AVAssetWriterInput) throws {
    guard let reader = self.reader else {
      throw AssetExportSessionError.nilReader
    }
    guard let writer = self.writer else {
      throw AssetExportSessionError.nilWriter
    }
    
    while input.isReadyForMoreMediaData || reader.status != .completed {
      let sampleBuffer = output.copyNextSampleBuffer()
      if let sampleBuffer = sampleBuffer {
        var handled = false
        var error = false
        
        if reader.status != .reading || writer.status != .writing {
          handled = true
          error = true
        }
        
        if !handled && self.videoOutput == output {
          // update the video progress
          self.lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
          self.lastSamplePresentationTime = CMTimeSubtract(lastSamplePresentationTime, self.timeRange.start)
          self.progress = self.duration == 0 ? 1 : CMTimeGetSeconds(self.lastSamplePresentationTime) / self.duration
          let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)
          var renderBuffer: CVPixelBuffer? = nil
          CVPixelBufferPoolCreatePixelBuffer(nil, self.videoPixelBufferAdaptor!.pixelBufferPool!, &renderBuffer)
          self.delegate?.exportSession(self, renderFrame: pixelBuffer!, withPresentationTime: self.lastSamplePresentationTime!, to: renderBuffer)
          if let aBuffer = renderBuffer, input.isReadyForMoreMediaData {
            if !self.videoPixelBufferAdaptor!.append(aBuffer, withPresentationTime: self.lastSamplePresentationTime!) {
              error = true
            }
          }
          handled = true
        }
        
        if !handled && input.isReadyForMoreMediaData && !input.append(sampleBuffer) {
          error = true
        }
        
        if error {
//          throw AssetExportSessionError.sessionError(details: "Something went wrong")
        }
      } else {
        if reader.status == .completed {
          input.markAsFinished()
          break
        }
//        } else {
//          continue
//        }
      }
    }
  }
  
  func getStatus() -> AVAssetExportSessionStatus {
    switch writer!.status {
    case .writing:
      return .exporting
    case .failed:
      return .failed
    case .completed:
      return .completed
    case .cancelled:
      return .cancelled
    case .unknown:
      fallthrough
    default:
      return .unknown
    }
  }
  
  func finish() throws {
    guard let reader = self.reader else {
      throw AssetExportSessionError.nilReader
    }
    guard let writer = self.writer else {
      throw AssetExportSessionError.nilWriter
    }
    // Synchronized block to ensure we never cancel the writer before calling finishWritingWithCompletionHandler
    if reader.status == .cancelled || writer.status == .cancelled {
      return
    }
    if writer.status == .failed {
      try complete()
    } else if reader.status == .failed {
      writer.cancelWriting()
      try complete()
    } else {
      let dispatchGroup = DispatchGroup()
      dispatchGroup.enter()
      writer.finishWriting(completionHandler: {
        try? self.complete()
        dispatchGroup.leave()
      })
      _ = dispatchGroup.wait(timeout: .distantFuture)
    }
  }
  
  func complete() throws {
//    guard let reader = self.reader else {
//      throw AssetExportSessionError.nilReader
//    }
    guard let writer = self.writer else {
      throw AssetExportSessionError.nilWriter
    }
    if writer.status == .failed || writer.status == .cancelled {
      try? FileManager.default.removeItem(at: self.outputURL)
    }
    if completionHandler != nil {
      self.completionHandler?()
      completionHandler = nil
    }
  }
  
  func getError() -> Error? {
    return self.error ?? self.writer?.error ?? self.reader?.error
  }
  
  func reset() {
    error = nil
    progress = 0
    reader = nil
    videoOutput = nil
    audioOutput = nil
    writer = nil
    videoInput = nil
    videoPixelBufferAdaptor = nil
    audioInput = nil
    completionHandler = nil
  }

}
