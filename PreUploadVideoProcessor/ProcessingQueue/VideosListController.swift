//
//  VideosListController.swift
//  PreUploadVideoProcessor
//
//  Created by Sergey Petrachkov on 14/08/2018.
//  Copyright © 2018 Sergey Petrachkov. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import AVKit
import Photos


class WCITNavigationController: UINavigationController {
  override func viewDidLoad() {
    super.viewDidLoad()
    self.applyNavigationBarTheme(backgroundColor: .black)
    self.navigationBar.isTranslucent = false
    self.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  public func applyNavigationBarTheme(backgroundColor color: UIColor, shadowImage: UIImage? = nil, tintColor: UIColor = .white) {
    let backgroundImage = UIImage(color: color)
    self.navigationBar.setBackgroundImage(backgroundImage, for: .default)
    self.navigationBar.shadowImage = shadowImage
    self.navigationBar.tintColor = tintColor
  }
}
extension UIImage {
  public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
    let rect = CGRect(origin: .zero, size: size)
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
    color.setFill()
    UIRectFill(rect)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    guard let cgImage = image?.cgImage else { return nil }
    self.init(cgImage: cgImage)
  }
}

extension UIViewController {
  @objc func didTapDismiss() {
    self.dismiss(animated: true, completion: nil)
  }
}


class VideosListController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SDAVAssetExportSessionDelegate, AssetExportSessionDelegate {
  
  let imagePickerController: UIImagePickerController = {
    let controller = UIImagePickerController()
    controller.sourceType = .photoLibrary
    controller.mediaTypes = ["public.movie"]
    controller.allowsEditing = false
    controller.videoExportPreset = AVAssetExportPreset960x540
    
    return controller
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.didTapPlus))
    self.imagePickerController.delegate = self
    self.authorizeToAlbum(completion: { result in })
  }
  func authorizeToAlbum(completion:@escaping (Bool)->Void) {
    
    if PHPhotoLibrary.authorizationStatus() != .authorized {
      NSLog("Will request authorization")
      PHPhotoLibrary.requestAuthorization({ (status) in
        if status == .authorized {
          DispatchQueue.main.async(execute: {
            completion(true)
          })
        } else {
          DispatchQueue.main.async(execute: {
            completion(false)
          })
        }
      })
      
    } else {
      DispatchQueue.main.async(execute: {
        completion(true)
      })
    }
  }
  
  @objc private func didTapPlus() {
    self.present(self.imagePickerController, animated: true, completion: nil)
  }
  
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    
    if let videoURL = info[UIImagePickerControllerMediaURL] as? URL {
//      DispatchQueue.main.async {
        picker.dismiss(animated: true, completion: nil)
//      }
      
      let tempDirectory = NSTemporaryDirectory()
      let processedURL = URL(fileURLWithPath: tempDirectory.appending(UUID().uuidString).appending(".mp4"))
      
      let asset = AVAsset(url: videoURL)
      
      let encoder = AssetExportSession(asset: asset,
                                       outputUrl: processedURL,
                                       outputFileType: .mp4,
                                       videoSettings: [
                                        AVVideoCodecKey: AVVideoCodecType.h264,
                                        AVVideoWidthKey: 600,
                                        AVVideoHeightKey: 400],
                                       audioSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 2, AVSampleRateKey: 44100, AVEncoderBitRateKey: 128000])
      encoder.delegate = self
      
      do {
        try encoder.exportAsynchronously {
            print(encoder.getStatus())
          DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges({
              PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: processedURL)
            }) { saved, error in
              if saved {
                let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(defaultAction)
                self.present(alertController, animated: true, completion: nil)
              }
            }
          }
//

        }
      } catch let error {
        print("\(error)")
      }
    }
  }
  
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }
  
  func exportSession(_ exportSession: AssetExportSession?, renderFrame pixelBuffer: CVPixelBuffer?, withPresentationTime presentationTime: CMTime, to renderBuffer: CVPixelBuffer?) {
    print(exportSession)
  }
  
  func exportSession(_ exportSession: SDAVAssetExportSession!, renderFrame pixelBuffer: CVPixelBuffer!, withPresentationTime presentationTime: CMTime, to renderBuffer: CVPixelBuffer!) {
    print(exportSession)
  }
}
