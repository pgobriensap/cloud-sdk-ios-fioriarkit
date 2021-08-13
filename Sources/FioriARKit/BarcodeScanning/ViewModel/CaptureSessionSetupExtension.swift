//
//  File.swift
//  
//
//  Created by Diaz, Ernesto on 8/13/21.
//

import Foundation
import AVFoundation
import UIKit
import Vision

extension CaptureSessionVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let exifOrientation = CaptureSessionUtils.exifOrientationFromDeviceOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform([self.detectBarcodeRequest])
        } catch {
            print(error)
        }
    }
    
    public func setupSession() {
        self.setupAVCapture()
        self.setupLayers()
        self.updateLayerGeometry()
        self.setupSlider()
        self.setupTapToFocus()
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
    
    func setupSlider() {
        let mySlider = UISlider(frame: CGRect(x: 0, y: 0, width: 300, height: 20))
        mySlider.center = CGPoint(x: 207, y: view.bounds.maxY - 160)
        view.addSubview(mySlider)
        
        mySlider.minimumValue = 0
        mySlider.maximumValue = 1
        mySlider.isContinuous = true
        mySlider.addTarget(self, action: #selector(self.controlFocus), for: .valueChanged)
    }
    
    func setupTapToFocus() {
        let tg = UITapGestureRecognizer(target: self, action: #selector(self.tapToFocus))
        self.view.addGestureRecognizer(tg)
    }
    
    func stopCaptureSession() {
        self.captureSession.stopRunning()
    }
    
    // Clean up capture setup
    func teardownAVCapture() {
        self.previewLayer.removeFromSuperlayer()
        self.previewLayer = nil
    }
    
    func startCaptureSession() {
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?

        for format in self.videoDevice.formats {
            if format.isHighestPhotoQualitySupported {
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                            //
                    }
                }
            } else {

            }
        }

        if let bestFormat = bestFormat,
           let bestFrameRateRange = bestFrameRateRange
        {
            do {
                try self.videoDevice.lockForConfiguration()
                self.videoDevice.activeFormat = bestFormat
                self.captureSession.startRunning()

                self.videoDevice.unlockForConfiguration()
                print(self.videoDevice.activeFormat)
                print(self.captureSession.sessionPreset)
                self.videoDevice.unlockForConfiguration()
            } catch {
                print(error)
            }
        } else {
            self.captureSession.sessionPreset = .high
            self.captureSession.startRunning()
        }
    }

    
}
