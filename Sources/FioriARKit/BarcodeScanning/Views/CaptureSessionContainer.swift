//
//  CaptureSessionView.swift
//
//
//  Created by O'Brien, Patrick on 6/24/21.
//

import Foundation
import SwiftUI

internal struct CaptureSessionContainer: UIViewControllerRepresentable {
    typealias UIViewControllerType = CaptureSessionVC
    func makeUIViewController(context: Context) -> CaptureSessionVC {
        CaptureSessionVC()
    }
    
    func updateUIViewController(_ uiViewController: CaptureSessionVC, context: Context) {}
}
