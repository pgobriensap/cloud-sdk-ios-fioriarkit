//
//  CaptureSessionView.swift
//
//
//  Created by O'Brien, Patrick on 6/24/21.
//

import AVFoundation
import Foundation
import SwiftUI
import Vision

internal struct CaptureSessionContainer: UIViewControllerRepresentable {
    @Binding var discoveredBarcode: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> CaptureSessionVC {
        let vc = CaptureSessionVC()
        vc.barcodeDelegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CaptureSessionVC, context: Context) {}
    
    class Coordinator: NSObject, BarcodeDelegate {
        var parent: CaptureSessionContainer
        
        init(_ csVC: CaptureSessionContainer) {
            self.parent = csVC
        }
        
        func updateBarcode(payload: String) {
            self.parent.discoveredBarcode = payload
        }
    }

    typealias UIViewControllerType = CaptureSessionVC
}
