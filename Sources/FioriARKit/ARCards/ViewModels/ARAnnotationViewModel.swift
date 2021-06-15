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
    
    @Published internal var barcodePositions: [CGRectModel] = []
    
    /// When false it indicates that the Image or Object has not been discovered and the subsequent animations have finished
    /// When the Image/Object Anchor is discovered there is a 3 second delay for animations to complete until the ContentView with Cards and Markers are displayed
    @Published internal var discoveryFlowHasFinished = true
    
    @Published internal var barcodes: [BarcodeModel] = [BarcodeModel(id: "Deodorant", payload: "0012044045893", exists: false),
                                                        BarcodeModel(id: "O'Reilly", payload: "9781492074533", exists: false),
                                                        BarcodeModel(id: "Thinking in SwiftUI", payload: "9798626292411", exists: false),
                                                        BarcodeModel(id: "Dune", payload: "9780441013593", exists: false),
                                                        BarcodeModel(id: "Listerine", payload: "0072785103207", exists: false)]
    
    /// The ARImageAnchor or ARPlaneAnchor that is supplied by the ARSessionDelegate upon discovery of image or object in the physical world
    /// Stores useful information such as anchor position and image/object data. In the case of image anchor it is also used to instantiate an AnchorEntity
    private var arkitAnchor: ARAnchor?
    
    var detectBarcodeRequest: VNDetectBarcodesRequest {
        let barcodeRequest = VNDetectBarcodesRequest { request, error in
            self.processClassification(request, error)
        }
        barcodeRequest.symbologies = [.EAN13, .QR, .EAN8]
        
        return barcodeRequest
    }
    
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
            
            let req = results.compactMap { ($0 as? VNBarcodeObservation)?.payloadStringValue }
            for (index, position) in self.barcodePositions.enumerated() {
                if !req.contains(position.id) {
                    self.barcodePositions[index].isVisible = false
                }
            }
            
            for request in results {
                if let bestResult = request as? VNBarcodeObservation, let payload = bestResult.payloadStringValue {
                    let rect = bestResult
                    let screen = UIScreen.main.bounds
                    
                    let transform = CGAffineTransform.identity
                        .scaledBy(x: 1, y: -1)
                        .translatedBy(x: 0, y: -screen.height)
                        .scaledBy(x: screen.width, y: screen.height)

                    let convertedTopLeft = rect.topLeft.applying(transform)
                    let convertedTopRight = rect.topRight.applying(transform)
                    let convertedBottomLeft = rect.bottomLeft.applying(transform)
                    
                    let width = abs(convertedTopRight.x - convertedTopLeft.x)
                    let height = abs(convertedBottomLeft.y - convertedTopLeft.y)
                    let center = CGPoint(x: rect.boundingBox.midX, y: rect.boundingBox.midY).applying(transform)
                    
                    for (index, barcode) in self.barcodePositions.enumerated() {
                        if payload == barcode.id {
                            self.barcodePositions[index].position = center
                            
                            if bestResult.symbology == .EAN13 {
                                self.barcodePositions[index].size = CGSize(width: width, height: width)
                            } else {
                                self.barcodePositions[index].size = CGSize(width: height, height: height)
                            }
                            
                            self.barcodePositions[index].isVisible = true
                        }
                    }
                    
                    let blah = self.barcodePositions.map(\.id)
                    
                    if !blah.contains(payload) {
                        self.barcodePositions.append(CGRectModel(id: payload, position: center, size: CGSize(width: width, height: height), isVisible: true))
                    }
                    
                    //                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    //                    self.barcodePosition = nil
                    //                }
                    
                    for (index, barcode) in self.barcodes.enumerated() {
                        if barcode.payload == payload {
                            self.barcodes[index].exists = true
                        }
                    }
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
        guard self.frameCount.isMultiple(of: 15) else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage, orientation: .right, options: [:])
            
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

struct CGRectModel: Identifiable {
    var id: String
    var position: CGPoint
    var size: CGSize
    var isVisible: Bool
}
