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


class VideosListController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  let imagePickerController: UIImagePickerController = {
    let controller = UIImagePickerController()
    controller.sourceType = .photoLibrary
    controller.mediaTypes = ["public.movie"]
    controller.allowsEditing = false
    controller.videoExportPreset = AVAssetExportPreset640x480
    return controller
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.didTapPlus))
    self.imagePickerController.delegate = self
  }
  
  @objc private func didTapPlus() {
    self.present(self.imagePickerController, animated: true, completion: nil)
  }
  
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    if let videoURL = info[UIImagePickerControllerMediaURL] as? URL {
      let tempDirectory = NSTemporaryDirectory()
      let processedURL = URL(fileURLWithPath: tempDirectory.appending(UUID().uuidString).appending(".mp4"))
      print("\(videoURL) \(processedURL)")
    }
//    // Handle movie capture
//    NSURL *movieURL = [info objectForKey:
//      UIImagePickerControllerMediaURL];
//
//    NSURL *uploadURL = [NSURL fileURLWithPath:[[NSTemporaryDirectory() stringByAppendingPathComponent:[self randomString]] stringByAppendingString:@".mp4"]];
//
//    // Compress movie first
//    [self convertVideoToLowQuailtyWithInputURL:movieURL outputURL:uploadURL];
  }
  
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }
}
