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

public class CameraView: UIView {
    public weak var barcodeDelegate: BarcodeOutputDelegate?
    let barcodeRecognition: BarcodeTracking
    
    
//    override open func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        self.setupSession()
//
//    }
    
    public init(recognitionMode: BarcodeTracking, barcodeDelegate: BarcodeOutputDelegate) {
        self.barcodeRecognition = recognitionMode
        self.barcodeDelegate = barcodeDelegate
        super.init(frame: .zero)
        self.setupSession()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    //MARK: Variables
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
    
    //MARK: Vision Requests
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

    func toggleResolution() {
        self.bufferSize = self.bufferSize.equalTo(Resolution.normal) ? Resolution.hd : Resolution.normal
    }

    //MARK: Focus and Zoom functions
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
        let point = sender.location(in: self)
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
}

