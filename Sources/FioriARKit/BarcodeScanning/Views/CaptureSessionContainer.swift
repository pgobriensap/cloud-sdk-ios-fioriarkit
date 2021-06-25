//
//  CaptureSessionView.swift
//
//
//  Created by O'Brien, Patrick on 6/24/21.
//

import Foundation
import SwiftUI

internal struct CaptureSessionContainer: UIViewRepresentable {
    var captureStorage: BarcodeScanningViewModel
    
    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
