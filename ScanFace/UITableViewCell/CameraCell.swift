//
//  CameraCell.swift
//  ScanFace
//
//  Created by Nin Sreynuth on 22/8/25.
//

import UIKit
import AVFoundation
import MLKitVision
import MLKitFaceDetection

protocol CameraCellDelegate: AnyObject {
    func cameraCell(_ cell: CameraCell, didValidateFace success: Bool, reason: String)
}
class CameraCell: UITableViewCell {
    
    @IBOutlet weak var backgroundUIView : UIView!
    @IBOutlet weak var focusFrameImg    : UIImageView!
    @IBOutlet weak var centerPlusImg    : UIImageView!
    
    weak var delegate           : CameraCellDelegate?
    
    var captureSession          = AVCaptureSession()
    var cameraOutput            = AVCapturePhotoOutput()
    var previewLayer            = AVCaptureVideoPreviewLayer()
    
    var input                   : AVCaptureDeviceInput?
    
    private var faceDetector    : FaceDetector?
    
    private var overlayMaskLayer = CAShapeLayer()

    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        setupCaptureSession()
        setupOverlay()
        setupFaceDetector()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update preview layer frame when layout changes
        previewLayer.frame = backgroundUIView.bounds
        setupOverlay()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    // MARK: - Face Detector
    private func setupFaceDetector() {
        let options = FaceDetectorOptions()
        options.performanceMode = .accurate
        options.landmarkMode = .all
        options.classificationMode = .all
        faceDetector = FaceDetector.faceDetector(options: options)
    }
    
    // MARK: - Overlay
    private func setupOverlay() {
        // Remove old overlays if any
        backgroundUIView.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }
        
        // Transparent overlay
        let overlayView = UIView(frame: backgroundUIView.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlayView.isUserInteractionEnabled = false
        overlayView.tag = 999
        backgroundUIView.addSubview(overlayView)
        
        // Create hole exactly matching focusFrameImg's frame
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: overlayView.bounds)
        let rect = focusFrameImg.frame.insetBy(dx: 2.5, dy: 2.5) // shrink by 5 on each side
        let squarePath = UIBezierPath(rect: rect)
        path.append(squarePath)
        
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
        
        // Keep images above overlay
        backgroundUIView.bringSubviewToFront(focusFrameImg)
        backgroundUIView.bringSubviewToFront(centerPlusImg)
        
        // Place center plus at middle of focusFrameImg
        centerPlusImg.center = CGPoint(x: rect.midX, y: rect.midY)
    }

    
    private func setupCaptureSession() {
        let deviceSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front // you can change to .back if needed
        )
        
        guard let device = deviceSession.devices.first else { return }
        
        do {
            input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input!) {
                captureSession.addInput(input!)
                captureSession.sessionPreset = .photo
                
                // Replace PhotoOutput with VideoDataOutput for MLKit
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                
                if captureSession.canAddOutput(videoOutput) {
                    captureSession.addOutput(videoOutput)
                }
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.frame = backgroundUIView.bounds
                previewLayer.videoGravity = .resizeAspectFill
                backgroundUIView.layer.addSublayer(previewLayer)
                
                captureSession.startRunning()
//                if captureSession.canAddOutput(cameraOutput) {
//                    captureSession.addOutput(cameraOutput)
//
//                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//                    previewLayer.frame = backgroundUIView.bounds
//                    previewLayer.videoGravity = .resizeAspectFill
//                    backgroundUIView.layer.addSublayer(previewLayer)
//
//                    captureSession.startRunning()
//                }
            }
        } catch {
            print("Camera setup error:", error)
        }
        
        // Tap to focus
        backgroundUIView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(tapOnCameraView(_:)))
        )
    }
    
    @objc func tapOnCameraView(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: self.backgroundUIView)
        let screenSize = backgroundUIView.bounds.size
        let focusPoint = CGPoint(x: touchPoint.y / screenSize.height, y: 1.0 - touchPoint.x / screenSize.width)
        
        if let device = input?.device {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode            = AVCaptureDevice.FocusMode.autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest  = focusPoint
                    device.exposureMode             = AVCaptureDevice.ExposureMode.autoExpose
                }
                device.unlockForConfiguration()
                
            } catch {
                // Handle errors here
            }
        }
        
    }
}


extension CameraCell: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: - Process Frames
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation = .right
        
        let options = FaceDetectorOptions()
        options.performanceMode = .fast
        options.landmarkMode = .all
        options.classificationMode = .all
        
        let faceDetector = FaceDetector.faceDetector(options: options)
        
        faceDetector.process(visionImage) { faces, error in
            guard error == nil, let faces = faces else { return }
            
            if faces.count != 1 {
                self.delegate?.cameraCell(self, didValidateFace: false, reason: "Multiple or no faces detected")
                return
            }
            
            let face = faces[0]
            
            // 1. Check head angle (should be facing forward)
            if abs(face.headEulerAngleX) > 15 ||
                abs(face.headEulerAngleY) > 15 ||
                abs(face.headEulerAngleZ) > 15 {
                self.delegate?.cameraCell(self, didValidateFace: false, reason: "Face not straight")
                return
            }
            
            // 2. Brightness check
            let brightness = self.estimateBrightness(from: pixelBuffer)
            if brightness < 0.4 {
                self.delegate?.cameraCell(self, didValidateFace: false, reason: "Poor lighting")
                return
            }
            
            // 3. Glasses/Hat check (not supported directly)
            // Placeholder: always pass
            // Replace with custom model if needed
            
            self.delegate?.cameraCell(self, didValidateFace: true, reason: "Face validated successfully")
        }
    }
    
    // MARK: - Brightness Helper
    private func estimateBrightness(from pixelBuffer: CVPixelBuffer) -> CGFloat {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let lumaBuffer = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        let luma = UnsafeMutablePointer<UInt8>(OpaquePointer(lumaBuffer))
        var total: Int = 0
        for y in stride(from: 0, to: height, by: 10) {
            for x in stride(from: 0, to: width, by: 10) {
                let offset = y * CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) + x
                total += Int(luma?[offset] ?? 0)
            }
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        let sampleCount = (width/10) * (height/10)
        return CGFloat(total) / CGFloat(sampleCount) / 255.0
    }
    
    private func cropFace(from pixelBuffer: CVPixelBuffer, boundingBox: CGRect) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        // MLKit boundingBox is normalized
        let rect = CGRect(x: boundingBox.origin.x * width,
                          y: (1 - boundingBox.origin.y - boundingBox.height) * height,
                          width: boundingBox.width * width,
                          height: boundingBox.height * height)

        let cropped = ciImage.cropped(to: rect)
        let context = CIContext()
        if let cgImage = context.createCGImage(cropped, from: cropped.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
}

