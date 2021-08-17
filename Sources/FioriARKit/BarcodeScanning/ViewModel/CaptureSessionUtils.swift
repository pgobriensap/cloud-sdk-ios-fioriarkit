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

struct Resolution {
    static let normal = CGSize(width: 1920, height: 1080)
    static let hd = CGSize(width: 4032, height: 3024)
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




