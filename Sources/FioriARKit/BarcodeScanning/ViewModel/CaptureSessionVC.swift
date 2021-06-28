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
    public var discoveredBarcodes: Set<String> = []
    
    // Vision Requests
    var detectBarcodeRequest: VNDetectBarcodesRequest {
        let barcodeRequest = VNDetectBarcodesRequest { request, _ in
            DispatchQueue.main.async {
                guard let results = request.results else { return }
                self.processClassification(results)
            }
        }
        barcodeRequest.revision = VNDetectBarcodesRequestRevision1
        barcodeRequest.symbologies = [.QR, .EAN13]
        
        return barcodeRequest
    }

    var currentFrame = 1
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupAVCapture()
        self.setupLayers()
        self.updateLayerGeometry()
        self.startCaptureSession()
    }
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else { return }
        
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Unable to create Capture Device: \(error)")
        }
        
        self.captureSession.beginConfiguration()
        
        guard self.captureSession.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            self.captureSession.commitConfiguration()
            return
        }
        
        self.captureSession.addInput(deviceInput)
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
        self.rootLayer = self.view.layer
        self.previewLayer.frame = self.rootLayer.bounds
        self.rootLayer.addSublayer(self.previewLayer)
    }
    
    func startCaptureSession() {
        self.captureSession.startRunning()
    }
    
    // Clean up capture setup
    func teardownAVCapture() {
        self.previewLayer.removeFromSuperlayer()
        self.previewLayer = nil
    }
    
    func processClassification(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.detectionOverlay.sublayers = nil
        
        if results.isEmpty {
            self.discoveredBarcodes.removeAll()
        }
        
        for result in results {
            if let barcode = result as? VNBarcodeObservation, let payload = barcode.payloadStringValue {
                let objectBounds = VNImageRectForNormalizedRect(barcode.boundingBox, Int(self.bufferSize.width), Int(self.bufferSize.height))
                
                var barcodeLayer: CALayer?
                if barcode.symbology == .QR {
                    barcodeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
                } else {
                    if !self.discoveredBarcodes.contains(payload) {
                        let ean13BoundingBox = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height * 0.66, height: objectBounds.height))
                        barcodeLayer = self.createRoundedRectLayerWithBounds(ean13BoundingBox)
                        self.discoveredBarcodes.insert(payload)
                    }
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
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
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
        self.currentFrame += 1
        guard self.currentFrame.isMultiple(of: 5) else { return }
        
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
