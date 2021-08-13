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

open class CaptureSessionVC: UIViewController {
    public weak var barcodeDelegate: BarcodeOutputDelegate?
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupSession()

    }

    // Capture Session
    var bufferSize = Resolution.normal // CGSize(width: 4032, height: 3024) for high resolution
    var detectionOverlay: CALayer!
    var videoDevice: AVCaptureDevice!
    var rootLayer: CALayer!
    var captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    let videoDataOutput = AVCaptureVideoDataOutput()
    let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var deviceInput: AVCaptureDeviceInput!
    
    private var lastZoomFactor: CGFloat = 1.0
    private var previousBarcodesScanned: [String: CGFloat] = [:]
    private var discoveredBarcodes: [String: Extent] = [:]
    private var framesLeft = 10
    
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
        barcodeRequest.symbologies = BarcodeModel.acceptedBarcodes
        
        return barcodeRequest
    }

    func toggleResolution() {
        self.bufferSize = self.bufferSize.equalTo(Resolution.normal) ? Resolution.hd : Resolution.normal
    }

    //Focus and Zoom functions
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
    
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        let device = self.deviceInput.device

        // Return zoom value between the minimum and maximum zoom values
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            min(min(max(factor, CaptureSessionUtils.minimumZoom), CaptureSessionUtils.maximumZoom), device.activeFormat.videoMaxZoomFactor)
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
        let point = sender.location(in: self.view)
        let focusPoint = self.previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        
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
    
    //Processing Barcodes
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
                guard BarcodeModel.acceptedBarcodes.contains(barcode.symbology) else { return }

                let objectBounds = VNImageRectForNormalizedRect(barcode.boundingBox, Int(self.bufferSize.width), Int(self.bufferSize.height))
                var bb: CGRect = .zero
                
                if BarcodeModel.oneDimensionalBarcodes.contains(barcode.symbology) {
                    if let previous = previousBarcodesScanned[payload] {
                        let difference = abs(objectBounds.origin.y - previous)
                        if difference > objectBounds.height {
                            bb = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height * 0.30, height: objectBounds.height))
                        } else {
                            bb = CGRect(origin: CGPoint(x: objectBounds.origin.x, y: previous), size: CGSize(width: objectBounds.height * 0.30, height: objectBounds.height))
                        }
                        self.previousBarcodesScanned[payload] = objectBounds.origin.y
                    } else {
                        self.previousBarcodesScanned[payload] = objectBounds.origin.y
                        bb = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height * 0.30, height: objectBounds.height))
                    }
                }
                
                if BarcodeModel.twoDimensionalBarcodes.contains(barcode.symbology) {
                    bb = CGRect(origin: objectBounds.origin, size: CGSize(width: objectBounds.height, height: objectBounds.height))
                }
                
                if let lastExtent = self.discoveredBarcodes[payload] {
                    self.detectionOverlay.sublayers?.forEach {
                        if let layerName = $0.name {
                            if layerName == payload {
                                let translationAnimation = CaptureSessionUtils.createTranslationAnimation(from: $0.presentation()?.position ?? lastExtent.position, to: bb.center)
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
                    let barcodeLayer = CaptureSessionUtils.createRoundedRectLayerWithBounds(bb, payload)
                    self.detectionOverlay.addSublayer(barcodeLayer)
                    self.discoveredBarcodes[payload] = Extent(position: objectBounds.center, size: CGSize(width: bb.width, height: bb.height))
                }
                
                self.barcodeDelegate?.payloadOutput(payload: payload, symbology: barcode.symbology)
            }
        }
        
        self.updateLayerGeometry()
        CATransaction.commit()
    }
}

