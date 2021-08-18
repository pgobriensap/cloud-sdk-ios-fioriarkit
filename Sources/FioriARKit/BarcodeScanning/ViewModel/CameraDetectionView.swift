//
//  BarcodeScanningViewModel.swift
//  Examples
//
//  Created by O'Brien, Patrick on 1/20/21.
//

import AVFoundation
import Combine
import SwiftUI
import UIKit
import Vision

public class CameraDetectionView: UIView {
    public weak var barcodeDelegate: BarcodeOutputDelegate?
    let barcodeRecognition: BarcodeTracking
    
    var videoDevice: AVCaptureDevice!
    var captureSession = AVCaptureSession()
    let videoDataOutput = AVCaptureVideoDataOutput()
    let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var deviceInput: AVCaptureDeviceInput!
    
    var previousRes = Resolution.normal
    var bufferSize = Resolution.normal // CGSize(width: 4032, height: 3024) for high resolution
    var detectionOverlay: CALayer!

    private var lastZoomFactor: CGFloat = 1.0
    
    var detectBarcodeRequest: VNDetectBarcodesRequest {
        let barcodeRequest = VNDetectBarcodesRequest { request, _ in
            DispatchQueue.main.async {
                guard let results = request.results else { return }
                let barcodeObservations = results.compactMap { $0 as? VNBarcodeObservation }
                self.barcodeRecognition.processAnimatedClassification(barcodeObservations, view: self)
            }
        }
        
        barcodeRequest.revision = VNDetectBarcodesRequestRevision1
        barcodeRequest.symbologies = BarcodeModel.acceptedBarcodes
        
        return barcodeRequest
    }
    
    public init(recognitionMode: BarcodeTracking, barcodeDelegate: BarcodeOutputDelegate) {
        self.barcodeRecognition = recognitionMode
        self.barcodeDelegate = barcodeDelegate
        super.init(frame: .zero)
        
        self.setupAVCapture()
        self.setupLayers()
        self.updateLayerGeometry()
        self.setupSliders()
        self.setupResolutionToggle()
        self.setupTapToFocus()
        self.startCaptureSession()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if let connection = videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = UIDevice.current.orientation.videoOrientation
        }
    }

    func setupAVCapture() {
        self.videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) // .DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else { return }
        self.deviceInput = try! AVCaptureDeviceInput(device: self.videoDevice)
        
        self.captureSession.beginConfiguration()
        
        guard self.captureSession.canAddInput(self.deviceInput) else {
            print("Could not add video device input to the session")
            self.captureSession.commitConfiguration()
            return
        }
        
        self.captureSession.addInput(self.deviceInput)
        if self.captureSession.canAddOutput(self.videoDataOutput) {
            self.captureSession.addOutput(self.videoDataOutput)
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            self.captureSession.commitConfiguration()
            return
        }
        
        let captureConnection = self.videoDataOutput.connection(with: .video)
        captureConnection?.isEnabled = true
        do {
            try self.videoDevice.lockForConfiguration()
            if self.videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                self.videoDevice.focusMode = .continuousAutoFocus
            }
            self.videoDevice.unlockForConfiguration()
        } catch {
            print(error)
        }
        self.captureSession.commitConfiguration()
        
        self.videoPreviewLayer.session = self.captureSession
        self.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.pinch(_:)))
        self.addGestureRecognizer(pinchRecognizer)
    }
    
    func setupLayers() {
        self.detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        self.detectionOverlay.name = "DetectionOverlay"
        self.detectionOverlay.bounds = CGRect(x: 0.0,
                                              y: 0.0,
                                              width: self.bufferSize.width,
                                              height: self.bufferSize.height)
        self.detectionOverlay.position = CGPoint(x: self.videoPreviewLayer.bounds.midX, y: self.videoPreviewLayer.bounds.midY)
        self.videoPreviewLayer.addSublayer(self.detectionOverlay)
    }
    
    func updateLayerGeometry() {
        let bounds = self.videoPreviewLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / self.bufferSize.height
        let yScale: CGFloat = bounds.size.height / self.bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        self.detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        self.detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
    }

    @objc func toggleResolution() {
        do {
            try self.videoDevice.lockForConfiguration()
            self.captureSession.sessionPreset = previousRes.equalTo(Resolution.normal) ? .hd4K3840x2160 : .high
            previousRes = previousRes.equalTo(Resolution.normal) ? Resolution.hd : Resolution.normal
            self.videoDevice.unlockForConfiguration()
        } catch {
            print(error)
        }
    }

    // MARK: Focus
    
    @objc func controlFocus(_ sender: UISlider) {
        do {
            try self.videoDevice.lockForConfiguration()
            self.videoDevice.setFocusModeLocked(lensPosition: sender.value, completionHandler: { _ in
                // print(timestamp)
            })
            self.videoDevice.unlockForConfiguration()
            
        } catch {
            // just ignore
        }
    }
    
    // MARK: Zoom
    
    @objc func controlZoom(_ sender: UISlider) {
        do {
            try self.videoDevice.lockForConfiguration()
            self.videoDevice.videoZoomFactor = CGFloat(sender.value)
            self.videoDevice.unlockForConfiguration()
            
        } catch {
            // just ignore
        }
    }
    
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        let device = self.deviceInput.device
        let minimumZoom: CGFloat = 1.0
        let maximumZoom: CGFloat = 3.0
        
        // Return zoom value between the minimum and maximum zoom values
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        }

        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch {
                print("\(error.localizedDescription)")
            }
        }

        let newScaleFactor = minMaxZoom(pinch.scale * self.lastZoomFactor)

        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor)
        case .ended:
            self.lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: self.lastZoomFactor)
        default: break
        }
    }
    
    @objc func tapToFocus(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: self)
        let focusPoint = self.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        
        do {
            try self.videoDevice.lockForConfiguration()
            
            self.videoDevice.focusPointOfInterest = focusPoint
            // videoDevice.focusMode = .continuousAutoFocus
            self.videoDevice.focusMode = .autoFocus
            // device.focusMode = .locked
            self.videoDevice.exposurePointOfInterest = focusPoint
            self.videoDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
            self.videoDevice.unlockForConfiguration()
            
        } catch {
            // just ignore
        }
    }
}

public extension CameraDetectionView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    /// Convenience wrapper to get layer as its statically known type.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation {
        switch self {
        case UIDeviceOrientation.portrait:
            return AVCaptureVideoOrientation.portrait
        case UIDeviceOrientation.portraitUpsideDown:
            return AVCaptureVideoOrientation.portraitUpsideDown
        case UIDeviceOrientation.landscapeLeft:
            return AVCaptureVideoOrientation.landscapeRight
        case UIDeviceOrientation.landscapeRight:
            return AVCaptureVideoOrientation.landscapeLeft
        default:
            return AVCaptureVideoOrientation.portrait
        }
    }
}
