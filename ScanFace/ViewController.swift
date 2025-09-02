//
//  ViewController.swift
//  ScanFace
//
//  Created by Nin Sreynuth on 21/8/25.
//

import UIKit
import AVFoundation
import MLKitFaceDetection

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView    : UITableView!
    
    private var captureSession      : AVCaptureSession!
    private var previewLayer        : AVCaptureVideoPreviewLayer!
    
    var faceDetect                  : Bool?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        tableView.isScrollEnabled = false
        registerCell()
        setUpUI()
    }
    //MARK: Private function
    private func registerCell() {
        tableView.register(UINib(nibName: "CameraCell",          bundle: nil), forCellReuseIdentifier: "CameraCell")
        tableView.register(UINib(nibName: "TermofUseCell",       bundle: nil), forCellReuseIdentifier: "TermofUseCell")
    }

    private func setUpUI() {
        tableView.delegate   = self
        tableView.dataSource = self
    }
    func imageOrientation(deviceOrientation: UIDeviceOrientation, cameraPosition: AVCaptureDevice.Position) -> UIImage.Orientation {
      switch deviceOrientation {
      case .portrait:
        return cameraPosition == .front ? .leftMirrored : .right
      case .landscapeLeft:
        return cameraPosition == .front ? .downMirrored : .up
      case .portraitUpsideDown:
        return cameraPosition == .front ? .rightMirrored : .left
      case .landscapeRight:
        return cameraPosition == .front ? .upMirrored : .down
      case .faceDown, .faceUp, .unknown:
        return .up
      }
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource{
    func numberOfSections(in tableView: UITableView) -> Int {
        return CameraRollType.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let cameraRollType = CameraRollType(rawValue: section){
            switch cameraRollType{
            case .SCANCAMERA:
                return 1
            case .TERMOFUSE:
                return 1
            }
        }
        return Int()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // to switch row Type
        guard let cameraRollType = CameraRollType(rawValue: indexPath.section)else {
            return UITableViewCell()
        }
        switch cameraRollType{
        case .SCANCAMERA:
            let cell = tableView.dequeueReusableCell(withIdentifier: "CameraCell", for: indexPath) as! CameraCell
            cell.delegate = self   // ✅ assign delegate
            return cell
        case .TERMOFUSE:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TermofUseCell", for: indexPath) as! TermofUseCell
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let cameraRollType = CameraRollType(rawValue: indexPath.section)else {
            return CGFloat()
        }
        switch cameraRollType{
        case .SCANCAMERA:
            return 327
        case .TERMOFUSE:
            return UITableView.automaticDimension
        }
        
    }
}
//extension ViewController: CameraCellDelegate {
//    func cameraCell(_ cell: CameraCell, didDetectFaces faces: [Face]) {
//        print("✅ ViewController: Detected \(faces.count) face(s)")
//    }
//    
//    func cameraCellDidDetectNoFace(_ cell: CameraCell) {
//        print("⚠️ ViewController: No face detected")
//    }
//}
extension ViewController: CameraCellDelegate {
    func cameraCell(_ cell: CameraCell, didValidateFace success: Bool, reason: String) {
        if success {
            print("✅ Face validation passed: \(reason)")
        } else {
            print("❌ Face validation failed: \(reason)")
        }
    }
}
