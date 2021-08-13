//
//  File.swift
//
//
//  Created by Diaz, Ernesto on 8/13/21.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI
import UIKit
import Vision

struct CaptureSessionUtils {
    
    static let minimumZoom: CGFloat = 1.0
    static let maximumZoom: CGFloat = 3.0
    
    
    static func createTranslationAnimation(from startPosition: CGPoint, to endPosition: CGPoint) -> CABasicAnimation {
        let translationAnim = CABasicAnimation(keyPath: "position")
        translationAnim.fromValue = startPosition
        translationAnim.toValue = endPosition
        translationAnim.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        translationAnim.isRemovedOnCompletion = true
        translationAnim.fillMode = .forwards
        translationAnim.beginTime = 0
        return translationAnim
    }
    
    static func createRoundedRectLayerWithBounds(_ bounds: CGRect, _ layerName: String) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = layerName
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.6, 0.98, 0.6, 0.7])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    static func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
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

struct Resolution {
    static let normal = CGSize(width: 1920, height: 1080)
    static let hd = CGSize(width: 4032, height: 3024)
}

struct Extent {
    var position: CGPoint
    var size: CGSize
}

public protocol BarcodeOutputDelegate: AnyObject {
    func payloadOutput(payload: String, symbology: VNBarcodeSymbology)
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: self.midX, y: self.midY)
    }
}




