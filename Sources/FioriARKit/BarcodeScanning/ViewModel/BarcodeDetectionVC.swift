//
//  File.swift
//
//
//  Created by Diaz, Ernesto on 8/16/21.
//

import UIKit

class BarcodeDetectionVC: UIViewController {
    weak var barcodeDelegate: BarcodeOutputDelegate?
    var hasCameraViewControls: Bool!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let barcodeRecognition = BarcodeTracking()
        let cameraView = CameraDetectionView(recognitionMode: barcodeRecognition, hasCameraViewControls: hasCameraViewControls)
        cameraView.barcodeDelegate = barcodeDelegate
        self.view.addSubview(cameraView)
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        cameraView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        cameraView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        cameraView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
    }
}
