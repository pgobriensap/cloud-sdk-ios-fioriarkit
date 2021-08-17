//
//  File.swift
//  
//
//  Created by Diaz, Ernesto on 8/16/21.
//

import Foundation
import AVFoundation
import UIKit
import Vision

public protocol BarcodeOutputDelegate: AnyObject {
    func payloadOutput(payload: String, symbology: VNBarcodeSymbology)
}

public class BarcodeTracking {
    
    private var previousBarcodesScanned: [String: CGFloat] = [:]
    private var discoveredBarcodes: [String: Extent] = [:]
    private var framesLeft = 10
    
    
    func processAnimatedClassification(_ results: [VNBarcodeObservation], view: CameraView) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // Clean up logic in the future
        if results.isEmpty {
            self.framesLeft -= 1
        } else {
            self.framesLeft = 10
        }

        if self.framesLeft < 0 {
            view.detectionOverlay.sublayers = nil
            self.discoveredBarcodes.removeAll()
            self.framesLeft = 10
        }
        
        for barcode in results {
            if let payload = barcode.payloadStringValue {
                guard BarcodeModel.acceptedBarcodes.contains(barcode.symbology) else { return }

                let objectBounds = VNImageRectForNormalizedRect(barcode.boundingBox, Int(view.bufferSize.width), Int(view.bufferSize.height))
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
                    view.detectionOverlay.sublayers?.forEach {
                        if let layerName = $0.name {
                            if layerName == payload {
                                let translationAnimation = self.createTranslationAnimation(from: $0.presentation()?.position ?? lastExtent.position, to: bb.center)
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
                    view.detectionOverlay.addSublayer(barcodeLayer)
                    self.discoveredBarcodes[payload] = Extent(position: objectBounds.center, size: CGSize(width: bb.width, height: bb.height))
                }
                
                view.barcodeDelegate?.payloadOutput(payload: payload, symbology: barcode.symbology)
            }
        }
        
        view.updateLayerGeometry()
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
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect, _ layerName: String) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = layerName
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.6, 0.98, 0.6, 0.7])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
}
