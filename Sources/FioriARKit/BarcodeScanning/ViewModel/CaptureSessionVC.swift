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

public protocol BarcodeOutputDelegate: AnyObject {
    func payloadOutput(payload: String)
}

open class CaptureSessionVC: UIViewController {
    // Link to UIViewControllerRepresentable
    public weak var barcodeDelegate: BarcodeOutputDelegate?
    
    // Capture Session
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer!
    private var detectionOverlay: CALayer!
    var captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var discoveredBarcodes: [String: Extent] = [:]
    var deviceInput: AVCaptureDeviceInput!
    
    let minimumZoom: CGFloat = 1.0
    let maximumZoom: CGFloat = 3.0
    var lastZoomFactor: CGFloat = 1.0
    
    // Vision Requests
    var detectBarcodeRequest: VNDetectBarcodesRequest {
        let barcodeRequest = VNDetectBarcodesRequest { request, _ in
            DispatchQueue.main.async {
                guard let results = request.results else { return }
                let barcodeObservations = results.compactMap { $0 as? VNBarcodeObservation }
                self.processAnimatedClassification(barcodeObservations)
            }
        }
        
        barcodeRequest.revision = VNDetectBarcodesRequestRevision1
        barcodeRequest.symbologies = [.ean13, .qr]
        
        return barcodeRequest
    }

    var framesLeft = 20
    var currentFrame = 1
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupAVCapture()
        self.setupLayers()
        self.updateLayerGeometry()
        self.startCaptureSession()
    }
    
    func setupAVCapture() {
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else { return }
        
        do {
            self.deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Unable to create Capture Device: \(error)")
        }
        
        self.captureSession.beginConfiguration()
        self.captureSession.sessionPreset = .photo
        
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
            try videoDevice.lockForConfiguration()
            if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoDevice.focusMode = .continuousAutoFocus
            }
            let dimensions = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
            self.bufferSize.width = CGFloat(dimensions.width)
            self.bufferSize.height = CGFloat(dimensions.height)
            videoDevice.unlockForConfiguration()
        } catch {
            print(error)
        }
        self.captureSession.commitConfiguration()
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.rootLayer = view.layer
        self.previewLayer.frame = self.rootLayer.bounds
        self.rootLayer.addSublayer(self.previewLayer)
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.pinch(_:)))
        self.view.addGestureRecognizer(pinchRecognizer)
    }
    
    func startCaptureSession() {
        self.captureSession.startRunning()
    }
    
    // Clean up capture setup
    func teardownAVCapture() {
        self.previewLayer.removeFromSuperlayer()
        self.previewLayer = nil
    }
    
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        let device = self.deviceInput.device

        // Return zoom value between the minimum and maximum zoom values
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            min(min(max(factor, self.minimumZoom), self.maximumZoom), device.activeFormat.videoMaxZoomFactor)
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
    
    func processClassification(_ results: [VNBarcodeObservation]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.detectionOverlay.sublayers = nil
        
        if results.isEmpty {
            self.discoveredBarcodes.removeAll()
        }
        
        for barcode in results {
            if let payload = barcode.payloadStringValue {
                let objectBounds = VNImageRectForNormalizedRect(barcode.boundingBox, Int(self.bufferSize.width), Int(self.bufferSize.height))
                
                var barcodeLayer: CALayer?
                if barcode.symbology == .qr {
                    barcodeLayer = self.createRoundedRectLayerWithBounds(objectBounds, payload)
                } else {
                    // if !self.discoveredBarcodes.contains(payload) {
                    let ean13BoundingBox = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height * 0.66, height: objectBounds.height))
                    barcodeLayer = self.createRoundedRectLayerWithBounds(ean13BoundingBox, payload)
                    // self.discoveredBarcodes.insert(payload)
                    // }
                }
                
                if let barcodeLayer = barcodeLayer {
                    self.detectionOverlay.addSublayer(barcodeLayer)
                    self.barcodeDelegate?.payloadOutput(payload: payload)
                }
            }
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    func processAnimatedClassification(_ results: [VNBarcodeObservation]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // Clean up logic in the future
        if results.isEmpty {
            self.framesLeft -= 1
        } else {
            self.framesLeft = 20
        }
    
        if self.framesLeft < 0 {
            self.detectionOverlay.sublayers = nil
            self.discoveredBarcodes.removeAll()
            self.framesLeft = 20
        }

        for barcode in results {
            if let payload = barcode.payloadStringValue {
                guard barcode.symbology == .ean13 || barcode.symbology == .qr else { return }
                
                let objectBounds = VNImageRectForNormalizedRect(barcode.boundingBox, Int(self.bufferSize.width), Int(self.bufferSize.height))
                var bb: CGRect = .zero
                
                if barcode.symbology == .ean13 {
                    bb = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height * 0.66, height: objectBounds.height))
                }
                if barcode.symbology == .qr {
                    bb = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height, height: objectBounds.height))
                }
                
                if let lastExtent = self.discoveredBarcodes[payload] {
                    self.detectionOverlay.sublayers?.forEach {
                        if let layerName = $0.name {
                            if layerName == payload {
                                let translationAnimation = createTranslationAnimation(from: $0.presentation()?.position ?? lastExtent.position, to: bb.center)
                                let widthAnimation = createXAnimation(currentWidth: $0.presentation()?.bounds.width ?? lastExtent.size.width, newWidth: bb.width)
                                let heightAnimation = createYAnimation(currentWidth: $0.presentation()?.bounds.height ?? lastExtent.size.height, newWidth: bb.width)
                                
                                $0.removeAllAnimations()
                                $0.bounds = bb
                                $0.position = bb.center

                                let animationGroup = CAAnimationGroup()
                                animationGroup.animations = [translationAnimation, widthAnimation, heightAnimation]
                                animationGroup.duration = 0.25
                                $0.add(animationGroup, forKey: "AllAnimations")
                                self.discoveredBarcodes[payload] = Extent(position: bb.center, size: CGSize(width: bb.width, height: bb.height))
                            }
                        }
                    }
                } else {
                    let barcodeLayer = self.createRoundedRectLayerWithBounds(bb, payload)
                    self.detectionOverlay.addSublayer(barcodeLayer)
                    self.discoveredBarcodes[payload] = Extent(position: objectBounds.center, size: CGSize(width: bb.width, height: bb.height))
                }
                
                self.barcodeDelegate?.payloadOutput(payload: payload)
            }
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    func createTranslationAnimation(from startPosition: CGPoint, to endPosition: CGPoint) -> CABasicAnimation {
        let translationAnim = CABasicAnimation(keyPath: "position")
        translationAnim.fromValue = startPosition
        translationAnim.toValue = endPosition
        translationAnim.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        translationAnim.isRemovedOnCompletion = true
        translationAnim.fillMode = .forwards
        translationAnim.beginTime = 0
        return translationAnim
    }
    
    func createXAnimation(currentWidth: CGFloat, newWidth: CGFloat) -> CABasicAnimation {
        let scale = currentWidth / newWidth
        let translationAnim = CABasicAnimation(keyPath: "transform.scale.x")
        translationAnim.fromValue = 1
        translationAnim.toValue = scale
        translationAnim.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        translationAnim.isRemovedOnCompletion = true
        translationAnim.fillMode = .forwards
        translationAnim.beginTime = 0
        return translationAnim
    }
    
    func createYAnimation(currentWidth: CGFloat, newWidth: CGFloat) -> CABasicAnimation {
        let scale = currentWidth / newWidth
        let translationAnim = CABasicAnimation(keyPath: "transform.scale.y")
        translationAnim.fromValue = 1
        translationAnim.toValue = scale
        translationAnim.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        translationAnim.isRemovedOnCompletion = true
        translationAnim.fillMode = .forwards
        translationAnim.beginTime = 0
        return translationAnim
    }
    
    func setupLayers() {
        self.detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        self.detectionOverlay.name = "DetectionOverlay"
        self.detectionOverlay.bounds = CGRect(x: 0.0,
                                              y: 0.0,
                                              width: self.bufferSize.width,
                                              height: self.bufferSize.height)
        self.detectionOverlay.position = CGPoint(x: self.rootLayer.bounds.midX, y: self.rootLayer.bounds.midY)
        self.rootLayer.addSublayer(self.detectionOverlay)
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect, _ layerName: String) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = layerName
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.6, 0.98, 0.6, 0.7])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    func updateLayerGeometry() {
        let bounds = self.rootLayer.bounds
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
}

extension CaptureSessionVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        currentFrame += 1
//        guard currentFrame.isMultiple(of: 5) else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = self.exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform([self.detectBarcodeRequest])
        } catch {
            print(error)
        }
        
        if self.currentFrame > 10000 {
            self.currentFrame = 1
        }
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown: // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft: // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight: // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait: // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}

struct Extent {
    var position: CGPoint
    var size: CGSize
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: self.midX, y: self.midY)
    }
}
