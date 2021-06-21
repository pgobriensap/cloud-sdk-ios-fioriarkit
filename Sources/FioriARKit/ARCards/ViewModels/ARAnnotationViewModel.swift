//
//  ARAnnotationViewModel.swift
//  Examples
//
//  Created by O'Brien, Patrick on 1/20/21.
//

import ARKit
import Combine
import RealityKit
import SwiftUI

///  ViewModel for managing an ARCards experience. Provides and sets the annotation data/anchor locations to the view and the flow for the discovery animations.
open class ARAnnotationViewModel<CardItem: CardItemModel>: NSObject, ObservableObject, ARSessionDelegate {
    /// Manages all common functionality for the ARView
    internal var arManager: ARManagement = ARManager()
    
    /// An array of **ScreenAnnotations** which are displayed in the scene  contain the marker position and their card contents
    /// The annotations internal entities within this list should be in the ARView scene. Set by the annotation loading strategy
    @Published public internal(set) var annotations = [ScreenAnnotation<CardItem>]()
    
    /// The ScreenAnnotation that is focused on in the scene. The CardView and MarkerView will be in their selected states
    @Published public internal(set) var currentAnnotation: ScreenAnnotation<CardItem>?
    
    /// The position of the ARAnchor thats discovered
    @Published internal var anchorPosition: CGPoint?
    
    typealias Payload = String
    @Published internal var discoveredBarcodes: [Payload: BarcodeModel] = [:]
    
    /// When false it indicates that the Image or Object has not been discovered and the subsequent animations have finished
    /// When the Image/Object Anchor is discovered there is a 3 second delay for animations to complete until the ContentView with Cards and Markers are displayed
    @Published internal var discoveryFlowHasFinished = true
    
    @Published internal var neededBarcodes: [BarcodeModel] = [BarcodeModel(id: "0012044045893", title: "Deodorant", discovered: false, symbology: .EAN13),
                                                              BarcodeModel(id: "9781492074533", title: "O'Reilly", discovered: false, symbology: .EAN13),
                                                              BarcodeModel(id: "9798626292411", title: "Thinking in SwiftUI", discovered: false, symbology: .EAN13),
                                                              BarcodeModel(id: "9780441013593", title: "Dune", discovered: false, symbology: .EAN13),
                                                              BarcodeModel(id: "0072785103207", title: "Listerine", discovered: false, symbology: .EAN13)]
    
    /// The ARImageAnchor or ARPlaneAnchor that is supplied by the ARSessionDelegate upon discovery of image or object in the physical world
    /// Stores useful information such as anchor position and image/object data. In the case of image anchor it is also used to instantiate an AnchorEntity
    private var arkitAnchor: ARAnchor?
    
    var detectBarcodeRequest: VNDetectBarcodesRequest {
        let barcodeRequest = VNDetectBarcodesRequest { request, error in
            self.processClassification(request, error)
        }
        barcodeRequest.revision = VNDetectBarcodesRequestRevision1
        barcodeRequest.symbologies = [.QR, .EAN13]
        
        return barcodeRequest
    }
    
    var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Image processing"
        queue.qualityOfService = .userInteractive
        return queue
    }()
    
    private var imageSize: CGSize = .zero
    
    private var frameCount: Int = 0
    
    override public init() {
        super.init()
        self.arManager.arView?.session.delegate = self
        self.arManager.onSceneUpate = self.updateScene(on:)
    }
    
    // MARK: ViewModel Lifecycle
    
    /// Updates scene on frame change
    /// Used to project the location of the Entities from the world space onto the screen space
    /// Potential to add a closure here for developer to add logic on frame change
    public func updateScene(on event: SceneEvents.Update) {
        for (index, entity) in self.annotations.enumerated() {
            guard let projectedPoint = arManager.arView?.project(entity.marker.internalEnitity.position(relativeTo: nil)) else { return }
            self.annotations[index].screenPosition = projectedPoint
        }
    }
    
    internal func cleanUpSession() {
        self.annotations.removeAll()
        self.currentAnnotation = nil
        self.arManager.tearDown()
    }
    
    // MARK: Annotation Management
    
    /// Loads a strategy into the arModel and sets **annotations** member from the returned [ScreenAnnotation]
    public func load<Strategy: AnnotationLoadingStrategy>(loadingStrategy: Strategy) where CardItem == Strategy.CardItem {
        do { self.annotations = try loadingStrategy.load(with: self.arManager) } catch { print("Annotation Loading Error: \(error)") }
        self.currentAnnotation = self.annotations.first
    }
    
    /// Sets the visibility of the Marker View for  a CardItem identified by its ID *Note: The `MarkerAnchor` still exists in the scene*
    public func setMarkerVisibility(for id: CardItem.ID, to isVisible: Bool) {
        for (index, annotation) in self.annotations.enumerated() where annotation.id == id {
            self.annotations[index].setMarkerVisibility(to: isVisible)
        }
    }
    
    // The carousel must recalculate and refresh the size of its container on card removal/insertion to center cards
    //    public func setCardVisibility(for id: CardItem.ID, to isVisible: Bool) {
    //        for (index, annotation) in self.annotations.enumerated() {
    //            if annotation.id == id { annotations[index].setCardVisibility(to: isVisible) }
    //        }
    //    }
    // Cards are initially set to visible
    private func showAnnotationsAfterDiscoveryFlow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { self.discoveryFlowHasFinished = true }
            
            for (index, _) in self.annotations.enumerated() {
                self.annotations[index].setMarkerVisibility(to: true)
            }
        }
    }
    
    private func getAnchorPosition(for arAnchor: ARAnchor) -> CGPoint? {
        let anchorTranslation = SIMD3<Float>(x: arAnchor.transform.columns.3.x, y: arAnchor.transform.columns.3.y, z: arAnchor.transform.columns.3.z)
        guard let objectCenter = arManager.arView?.project(anchorTranslation) else { return nil }
        return objectCenter
    }
    
    func processClassification(_ request: VNRequest, _ error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else { return }
            
            if results.isEmpty {
                self.discoveredBarcodes.removeAll()
            }
            
            for request in results {
                if let barcode = request as? VNBarcodeObservation, let payload = barcode.payloadStringValue {
                    let screen = UIScreen.main.bounds
                    //
                    //                    let transform = CGAffineTransform.identity
                    //                        .scaledBy(x: 1, y: -1)
                    //                        .translatedBy(x: 0, y: -screen.height)
                    //                        .scaledBy(x: screen.width, y: screen.height)
                    //
                    //                    let convertedTopLeft = rect.topLeft.applying(transform)
                    //                    let convertedTopRight = rect.topRight.applying(transform)
                    //                    let convertedBottomLeft = rect.bottomLeft.applying(transform)
                    //
                    //                    let eanheight = abs(convertedTopRight.x - convertedTopLeft.x)
                    //                    let eanWidth = abs(convertedBottomLeft.y - convertedTopLeft.y)
                    //                    let eanCenter = CGPoint(x: rect.boundingBox.midX, y: rect.boundingBox.midY).applying(transform)
                    //
                    //
                    let center = CGPoint(x: barcode.boundingBox.midX * screen.width, y: (1 - barcode.boundingBox.midY) * screen.height)
                    let height = abs(barcode.boundingBox.maxY - barcode.boundingBox.minY) * screen.height
                    let width = abs(barcode.boundingBox.maxX - barcode.boundingBox.minX) * screen.width
                    
                    for (index, needed) in self.neededBarcodes.enumerated() where payload == needed.id {
                        self.neededBarcodes[index].discovered = true
                    }
                    
                    self.discoveredBarcodes[payload] = BarcodeModel(id: payload,
                                                                    title: payload,
                                                                    discovered: true,
                                                                    position: center,
                                                                    size: barcode.symbology == .QR ? CGSize(width: height, height: height) : CGSize(width: width, height: width * 0.66),
                                                                    symbology: barcode.symbology)
                }
            }
        }
    }
    
    // MARK: ARSession Delegate
    
    /// Tells the delegate that one or more anchors have been added to the session.
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        //        if let imageAnchor = anchors.compactMap({ $0 as? ARImageAnchor }).first {
        //            guard let root = arManager.sceneRoot else { return }
        //            self.arkitAnchor = imageAnchor
        //
        //            let anchorEntity = AnchorEntity(anchor: imageAnchor)
        //            anchorEntity.addChild(root)
        //            self.arManager.arView?.scene.addAnchor(anchorEntity)
        //
        //            self.showAnnotationsAfterDiscoveryFlow()
        //
        //        } else if let objectAnchor = anchors.compactMap({ $0 as? ARObjectAnchor }).first {
        //            self.arkitAnchor = objectAnchor
        //            self.showAnnotationsAfterDiscoveryFlow()
        //        }
    }
    
    /// Provides a newly captured camera image and accompanying AR information to the delegate.
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        //        guard !self.discoveryFlowHasFinished else { return }
        //
        //        if let arkitAnchor = arkitAnchor {
        //            self.anchorPosition = self.getAnchorPosition(for: arkitAnchor)
        //        }
        // Perform the classification request on a background thread.
        // let affineTransform = frame.displayTransform(for: .portrait, viewportSize: UIScreen.main.bounds.size)
        self.frameCount += 1
        if self.queue.operationCount > 0 { return }
        guard self.frameCount.isMultiple(of: 10) else { return }
        
        guard let interfaceOrientation = arManager.arView?.window?.windowScene?.interfaceOrientation else { return }
        
        self.imageSize = frame.capturedImage.size
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        guard let viewPort = arManager.arView?.bounds else { return }
        
        let normalizeTransform = CGAffineTransform(scaleX: 1.0 / self.imageSize.width, y: 1.0 / self.imageSize.height)
        let flipTransform = interfaceOrientation.isPortrait ? CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -1, y: -1) : .identity
        let displayTransform = frame.displayTransform(for: interfaceOrientation, viewportSize: viewPort.size)
        
        let toViewPortTransform = CGAffineTransform(scaleX: viewPort.size.width, y: viewPort.size.height)
        
        let transformedImage = ciImage
            .transformed(by: normalizeTransform
                .concatenating(flipTransform)
                .concatenating(displayTransform)
                .concatenating(toViewPortTransform)
            )
            .cropped(to: viewPort)
        
        // print("buffer: ", self.imageSize, "Screen: ", UIScreen.main.bounds)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: transformedImage)
            
            do {
                try handler.perform([self.detectBarcodeRequest])
            } catch {
                print("Request Error: \(error)")
            }
        }
        
        if self.frameCount > 10000 {
            self.frameCount = 1
        }
    }
}

extension CVPixelBuffer {
    var size: CGSize {
        let width = CGFloat(CVPixelBufferGetWidth(self))
        let height = CGFloat(CVPixelBufferGetHeight(self))
        return CGSize(width: width, height: height)
    }
}
