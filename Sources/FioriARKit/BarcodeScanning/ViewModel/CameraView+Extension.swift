//
//  File.swift
//
//
//  Created by Diaz, Ernesto on 8/13/21.
//

import AVFoundation
import Foundation
import UIKit
import Vision

extension CameraDetectionView: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let exifOrientation = self.exifOrientationFromDeviceOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform([self.detectBarcodeRequest])
        } catch {
            print(error)
        }
    }
    
    func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
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

extension CameraDetectionView {
    func setupSliders() {
        let focusSlider = UISlider(frame: CGRect(x: 0, y: 0, width: 300, height: 20))
        self.addSubview(focusSlider)
        focusSlider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            focusSlider.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            focusSlider.centerYAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: -150),
            focusSlider.widthAnchor.constraint(equalToConstant: focusSlider.bounds.width),
            focusSlider.heightAnchor.constraint(equalToConstant: focusSlider.bounds.height)
        ])
        focusSlider.minimumValue = 0
        focusSlider.maximumValue = 1
        focusSlider.isContinuous = true
        focusSlider.addTarget(self, action: #selector(self.controlFocus), for: .valueChanged)
    }
    
    func setupResolutionToggle() {
        let resToggle = UISwitch()
        resToggle.center = self.center
        resToggle.addTarget(self, action: #selector(self.toggleResolution), for: .valueChanged)
        self.addSubview(resToggle)
        resToggle.translatesAutoresizingMaskIntoConstraints = false
        resToggle.centerXAnchor.constraint(
            equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: -resToggle.bounds.width).isActive = true
        resToggle.centerYAnchor.constraint(
            equalTo: self.safeAreaLayoutGuide.topAnchor).isActive = true
    }

    func setupTapToFocus() {
        let tg = UITapGestureRecognizer(target: self, action: #selector(self.tapToFocus))
        self.addGestureRecognizer(tg)
    }
    
    func stopCaptureSession() {
        self.captureSession.stopRunning()
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
            } else {}
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
