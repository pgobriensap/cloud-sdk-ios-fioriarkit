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
    func payloadOutput(payload: String, symbology: VNBarcodeSymbology)
}

open class CaptureSessionVC: UIViewController {
    // Link to UIViewControllerRepresentable
    public weak var barcodeDelegate: BarcodeOutputDelegate?
    var videoDevice: AVCaptureDevice!
    
    // Capture Session
    var bufferSize = CGSize(width: 4032, height: 3024) // CGSize(width: 1920, height: 1080)
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
    
    var barcodes: [VNBarcodeObservation] = []
    var rectangles: [VNRectangleObservation] = []
    var queues: [String: [CGFloat]] = [:]
    var prev: [String: CGFloat] = [:]
    
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
        barcodeRequest.symbologies = [.QR, .EAN13, .EAN8, .Code128, .Code39, .UPCE]
        
        return barcodeRequest
    }
    
    var detectRectangleRequest: VNDetectRectanglesRequest {
        let rectangleRequest = VNDetectRectanglesRequest { request, _ in
            DispatchQueue.main.async {
                guard let results = request.results else { return }
                self.rectangles = results.compactMap { $0 as? VNRectangleObservation }
                // self.processRectangleClassification(rectangleObservations, barcodeResults)
            }
        }
        return rectangleRequest
    }
    
    var startSession: (() -> Void)?
    var stopSession: (() -> Void)?

    var framesLeft = 10
    var currentFrame = 1
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupAVCapture()
        self.setupLayers()
        self.updateLayerGeometry()
        self.startCaptureSession()
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
            let dimensions = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
            let height = UIScreen.main.bounds.height
            let width = UIScreen.main.bounds.width
            let scale = UIScreen.main.scale
            print("CMDimensions: Width: \(dimensions.width), Height: \(dimensions.height)")
            print("Sceen Dimensions: Width: \(scale * width), Height: \(scale * height)")
            // self.bufferSize.width = CGFloat(dimensions.width)
            // self.bufferSize.height = CGFloat(dimensions.height)
            self.videoDevice.unlockForConfiguration()
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
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        // var setExposure: Exposure = .min

        for format in self.videoDevice.formats {
            // print("+++++++")
            // print(format)
            if format.isHighestPhotoQualitySupported {
                // print("True")
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                        bestFormat = format
                        bestFrameRateRange = range
                    }
                }
            } else {
                // print("False")
            }
            // print("=========")
        }
        
//        captureSession.sessionPreset = AVCaptureSession.Preset.inputPriority // Required for the "activeFormat" of the device to be used
//        let highresFormat = videoDevice.formats
//            .filter { CMFormatDescriptionGetMediaSubType($0.formatDescription) == 875704422 }
//            .max { a, b in CMVideoFormatDescriptionGetDimensions(a.formatDescription).width < CMVideoFormatDescriptionGetDimensions(b.formatDescription).width }
//
//        if let format = highresFormat {
//            bestFormat = format
//        }

        if let bestFormat = bestFormat,
           let bestFrameRateRange = bestFrameRateRange
        {
            do {
                try self.videoDevice.lockForConfiguration()
                // Set the device's active format.
                self.videoDevice.activeFormat = bestFormat

                // Set the device's min/max frame duration.
//                let duration = bestFrameRateRange.minFrameDuration
//                self.videoDevice.activeVideoMinFrameDuration = duration
//                self.videoDevice.activeVideoMaxFrameDuration = duration
                
                // if videoDevice.isExposureModeSupported(.custom) {
                // self.videoDevice.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: setExposure.value(device: videoDevice)) { _ in
                //  print("Done Esposure")
                // }
                // }
                self.captureSession.startRunning()

                self.videoDevice.unlockForConfiguration()
                print(self.videoDevice.activeFormat)
                print(self.captureSession.sessionPreset)
                // print(self.videoDevice.exposureMode.rawValue)
                self.videoDevice.unlockForConfiguration()
            } catch {
                print(error)
            }
        } else {
            self.captureSession.sessionPreset = .high
            self.captureSession.startRunning()
        }
    }
    
    func stopCaptureSession() {
        self.captureSession.stopRunning()
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
    
    func processRectangleClassification(_ results: [VNRectangleObservation]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.detectionOverlay.sublayers = nil
        
        for rectangle in results {
            let objectBounds = VNImageRectForNormalizedRect(rectangle.boundingBox, Int(self.bufferSize.width), Int(self.bufferSize.height))
            let barcodeLayer = self.createRoundedRectLayerWithBounds(objectBounds, "")
            self.detectionOverlay.addSublayer(barcodeLayer)
        }
        self.updateLayerGeometry()
        CATransaction.commit()
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
                if barcode.symbology == .QR {
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
                    self.barcodeDelegate?.payloadOutput(payload: payload, symbology: barcode.symbology)
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
            self.framesLeft = 10
        }
    
        if self.framesLeft < 0 {
            self.detectionOverlay.sublayers = nil
            self.discoveredBarcodes.removeAll()
            self.framesLeft = 10
        }
        
        for barcode in results {
            if let payload = barcode.payloadStringValue {
                guard [.QR, .EAN13, .EAN8, .Code128, .Code39, .UPCE].contains(barcode.symbology) else { return }

                let objectBounds = VNImageRectForNormalizedRect(barcode.boundingBox, Int(self.bufferSize.width), Int(self.bufferSize.height))
                // print("inside", self.bufferSize)
                var bb: CGRect = .zero
                
                if [.EAN13, .EAN8, .Code128, .Code39, .UPCE].contains(barcode.symbology) {
                    if var previous = prev[payload] {
                        let difference = abs(objectBounds.origin.y - previous)
                        if difference > objectBounds.height {
                            bb = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height * 0.30, height: objectBounds.height))
                        } else {
                            bb = CGRect(origin: CGPoint(x: objectBounds.origin.x, y: previous), size: CGSize(width: objectBounds.height * 0.30, height: objectBounds.height))
                        }
                        self.prev[payload] = objectBounds.origin.y
                    } else {
                        self.prev[payload] = objectBounds.origin.y
                        bb = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height * 0.30, height: objectBounds.height))
                    }
                }
                
                if barcode.symbology == .QR {
                    bb = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height, height: objectBounds.height))
                }
                
                if let lastExtent = self.discoveredBarcodes[payload] {
                    self.detectionOverlay.sublayers?.forEach {
                        if let layerName = $0.name {
                            if layerName == payload {
                                let translationAnimation = createTranslationAnimation(from: $0.presentation()?.position ?? lastExtent.position, to: bb.center)
                                // let widthAnimation = createXAnimation(currentWidth: $0.presentation()?.bounds.width ?? lastExtent.size.width, newWidth: bb.width)
                                // let heightAnimation = createYAnimation(currentWidth: $0.presentation()?.bounds.height ?? lastExtent.size.height, newWidth: bb.width)
                                
                                $0.removeAllAnimations()
                                $0.bounds = bb
                                $0.position = bb.center

                                let animationGroup = CAAnimationGroup()
                                animationGroup.animations = [translationAnimation]
                                animationGroup.duration = 0.15
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
                
                self.barcodeDelegate?.payloadOutput(payload: payload, symbology: barcode.symbology)
            }
        }
        
        // Clean up discovered Overlays that are not rediscovered
//        for (payloadString, _) in discoveredBarcodes {
//            if !results.compactMap({ $0.payloadStringValue }).contains(payloadString) {
//                discoveredBarcodes.removeValue(forKey: payloadString)
//            }
//        }
        
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
        
        let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!

        // Lock the base Address
//        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
//        self.bufferSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
//        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let exifOrientation = self.exifOrientationFromDeviceOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform([self.detectBarcodeRequest])
        } catch {
            print(error)
        }
        
//        if currentFrame == 10000 {
//            currentFrame = 1
//        }
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

enum Exposure {
    case min, normal, max
    
    func value(device: AVCaptureDevice) -> Float {
        switch self {
        case .min:
            return device.activeFormat.minISO
        case .normal:
            return AVCaptureDevice.currentISO
        case .max:
            return device.activeFormat.maxISO
        }
    }
}

struct TenQueue: CustomStringConvertible {
    private var internalArray: [CGFloat] = []
    
    var description: String {
        internalArray.description
    }
    
    mutating func push(_ element: CGFloat) {
        self.internalArray.insert(element, at: 0)
        
        if self.internalArray.count > 10 {
            self.internalArray = self.internalArray.dropLast()
        }
    }
    
    func getAvg() -> CGFloat {
        let sum = self.internalArray.reduce(.zero, +)
        let avg = CGFloat(internalArray.count) / sum
        return avg
    }
    
    func count() -> Int {
        self.internalArray.count
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
