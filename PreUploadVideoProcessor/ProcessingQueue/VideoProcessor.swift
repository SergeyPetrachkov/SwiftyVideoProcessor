//
//  VideoProcessor.swift
//  PreUploadVideoProcessor
//
//  Created by Sergey Petrachkov on 14/08/2018.
//  Copyright © 2018 Sergey Petrachkov. All rights reserved.
//

import Foundation
import AVFoundation
//
//protocol SDAVAssetExportSessionDelegate: NSObjectProtocol {
//  func exportSession(_ exportSession: SDAVAssetExportSession?, renderFrame pixelBuffer: CVPixelBuffer?, withPresentationTime presentationTime: CMTime, to renderBuffer: CVPixelBuffer?)
//}
//
//class SDAVAssetExportSession: NSObject {
//  weak var delegate: SDAVAssetExportSessionDelegate?
//  private(set) var asset: AVAsset?
//  var videoComposition: AVVideoComposition?
//  var audioMix: AVAudioMix?
//  var outputFileType = ""
//  var outputURL: URL?
//  var videoInputSettings: [AnyHashable : Any] = [:]
//  var videoSettings: [AnyHashable : Any] = [:]
//  var audioSettings: [AnyHashable : Any] = [:]
//  var timeRange: CMTimeRange?
//  var shouldOptimizeForNetworkUse = false
//  var metadata: [Any] = []
//  
//  private(set) var error: Error?
//  private(set) var progress: Double = 0.0
//  private(set) var status: AVAssetExportSessionStatus?
//  
//  var reader: AVAssetReader?
//  var videoOutput: AVAssetReaderVideoCompositionOutput?
//  var audioOutput: AVAssetReaderAudioMixOutput?
//  var writer: AVAssetWriter?
//  var videoInput: AVAssetWriterInput?
//  var videoPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
//  var audioInput: AVAssetWriterInput?
//  var inputQueue: DispatchQueue?
//  var completionHandler: (() -> Void)?
//  
//  private var duration: TimeInterval = 0.0
//  private var lastSamplePresentationTime: CMTime?
//  
//  convenience init?(asset: AVAsset?) {
//    guard let asset = asset else {
//      return nil
//    }
//    self.init(asset: asset)
//  }
//  
//  init(asset: AVAsset) {
//    self.asset = asset
//  }
//  
//  func exportAsynchronously(completionHandler handler: @escaping () -> Void) {
//    self.cancelExport()
//    completionHandler = handler
//    if outputURL == nil {
//      error = NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: "Output URL not set"])
//      handler()
//      return
//    }
//    var readerError: Error?
//    reader = try? AVAssetReader(asset: asset)
//    if readerError != nil {
//      error = readerError
//      handler()
//      return
//    }
//    var writerError: Error?
//    if let anURL = outputURL, let aType = outputFileType {
//      writer = try? AVAssetWriter(url: anURL, fileType: aType)
//    }
//    if writerError != nil {
//      error = writerError
//      handler()
//      return
//    }
//    reader.timeRange = timeRange
//    writer.shouldOptimizeForNetworkUse = shouldOptimizeForNetworkUse
//    writer.metadata = metadata
//    var videoTracks = asset.tracks(withMediaType: .video)
//    if CMTIME_IS_VALID(timeRange.duration) && !CMTIME_IS_POSITIVE_INFINITY(timeRange.duration) {
//      duration = CMTimeGetSeconds(timeRange.duration)
//    } else {
//      duration = CMTimeGetSeconds(asset.duration)
//    }
//    //
//    // Video output
//    //
//    if videoTracks.count > 0 {
//      videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: videoInputSettings)
//      videoOutput.alwaysCopiesSampleData = false
//      if videoComposition != nil {
//        videoOutput.videoComposition = videoComposition
//      } else {
//        videoOutput.videoComposition = buildDefaultVideoComposition()
//      }
//      if reader.canAdd(videoOutput) {
//        reader.add(videoOutput)
//      }
//      //
//      // Video input
//      //
//      videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
//      videoInput.expectsMediaDataInRealTime = false
//      if writer.canAdd(videoInput) {
//        writer.add(videoInput)
//      }
//      
//      
//    }
//    
//    
//  }
//  
//  func cancelExport() {
//    if let inputQueue = self.inputQueue {
//      inputQueue.async(execute: {
//        self.writer?.cancelWriting()
//        self.reader?.cancelReading()
//        self.complete()
//        self.reset()
//      })
//    }
//  }
//  
//  func encodeReadySamples(from output: AVAssetReaderOutput, to input: AVAssetWriterInput) -> Bool {
//    while input.isReadyForMoreMediaData {
//      var sampleBuffer = output.copyNextSampleBuffer()
//      if let sampleBuffer = sampleBuffer {
//        var handled = false
//        var error = false
//        if reader!.status != .reading || writer!.status != .writing {
//          handled = true
//          error = true
//        }
//        if !handled && videoOutput == output {
//          // update the video progress
//          lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//          lastSamplePresentationTime = CMTimeSubtract(lastSamplePresentationTime!, timeRange!.start)
//          progress = duration == 0 ? 1 : CMTimeGetSeconds(lastSamplePresentationTime!) / duration
////          if self.delegate?.responds(to: #selector(self.exportSession(_:renderFrame:withPresentationTime:toBuffer:)))  == true {
//            var pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) as? CVPixelBuffer?
//            var renderBuffer: CVPixelBuffer? = nil
//            CVPixelBufferPoolCreatePixelBuffer(nil, videoPixelBufferAdaptor!.pixelBufferPool!, &renderBuffer)
//            self.delegate?.exportSession(self, renderFrame: pixelBuffer!, withPresentationTime: lastSamplePresentationTime!, to: renderBuffer)
//            if let aBuffer = renderBuffer {
//              if !videoPixelBufferAdaptor!.append(aBuffer, withPresentationTime: lastSamplePresentationTime!) {
//                error = true
//              }
//            }
////            CVPixelBufferRelease(renderBuffer)
//            handled = true
////          }
//        }
//        if sampleBuffer != nil {
//          if !handled && !input.append(sampleBuffer) {
//            error = true
//          }
//        }
//        if error != nil {
//          return false
//        }
//      } else {
//        input.markAsFinished()
//        return false
//      }
//    }
//    return true
//  }
//  
//  private func getStatus() -> AVAssetExportSessionStatus {
//    switch writer!.status {
//    case .writing:
//      return .exporting
//    case .failed:
//      return .failed
//    case .completed:
//      return .completed
//    case .cancelled:
//      return .cancelled
//    case .unknown:
//      fallthrough
//    default:
//      return .unknown
//    }
//  }
//  
//  func finish() {
//    // Synchronized block to ensure we never cancel the writer before calling finishWritingWithCompletionHandler
//    if reader!.status == .cancelled || writer!.status == .cancelled {
//      return
//    }
//    if writer!.status == .failed {
//      complete()
//    } else if reader!.status == .failed {
//      writer!.cancelWriting()
//      complete()
//    } else {
//      writer!.finishWriting(completionHandler: {
//        self.complete()
//      })
//    }
//  }
//  
//  func complete() {
//    if writer!.status == .failed || writer!.status == .cancelled {
//      if let anURL = outputURL {
//        try? FileManager.default.removeItem(at: anURL)
//      }
//    }
//    if completionHandler != nil {
//      self.completionHandler?()
//      completionHandler = nil
//    }
//  }
//  
//  func getError() -> Error? {
//    if error != nil {
//      return error
//    } else {
//      return writer?.error ?? reader?.error
//    }
//  }
//  
//  func reset() {
//    error = nil
//    progress = 0
//    reader = nil
//    videoOutput = nil
//    audioOutput = nil
//    writer = nil
//    videoInput = nil
//    videoPixelBufferAdaptor = nil
//    audioInput = nil
//    inputQueue = nil
//    completionHandler = nil
//  }
//
//}
