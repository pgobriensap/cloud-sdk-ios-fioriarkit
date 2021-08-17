//
//  File.swift
//  
//
//  Created by Diaz, Ernesto on 8/16/21.
//

import UIKit

class BarcodeDetectionVC: UIViewController {
    var barcodeDelegate: BarcodeOutputDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        let barcodeRecognition = BarcodeTracking()
        let cameraView = CameraView(recognitionMode: barcodeRecognition, barcodeDelegate: self.barcodeDelegate!)
//        cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        cameraView.frame = view.bounds
//        cameraView.center = CGPoint(x: 100, y: 100)
        self.view.addSubview(cameraView)
        
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        cameraView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        cameraView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        cameraView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true

        self.view.bringSubviewToFront(cameraView)
    }
}
