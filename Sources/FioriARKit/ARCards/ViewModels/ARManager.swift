//
//  ARManager.swift
//
//
//  Created by O'Brien, Patrick on 5/21/21.
//

import ARKit
import Combine
import RealityKit
import SwiftUI

/// Stores and manages common functional for the ARView
///
/// - Parameters:
///  - arView: The RealityKit ARView which provides the scene and ARSession for the AR Experience
///  - sceneRoot: The root for a strategy which uses a single Anchor
///  - onSceneUpate: Closure which is called on every frame update
///  - worldMap: Optional stored reference for a ARWorldMap
///  - referenceImages: List of current ARReferenceImages which have been loaded into the configuration
///  - detectionObjects: List of current ARReferenceImages which have been loaded into the configuration
/// ```
public class ARManager: ARManagement {
    public var arView: ARView?
    public var sceneRoot: HasAnchoring?
    public var onSceneUpate: ((SceneEvents.Update) -> Void)?
    
    var worldMap: ARWorldMap?
    var referenceImages: Set<ARReferenceImage> = []
    var detectionObjects: Set<ARReferenceObject> = []
    
    var subscription: Cancellable!
    
    var elevation: CGPoint?
    var selectedEntity: Entity?
    
    public init() {
        self.arView = ARView(frame: .zero)
        self.arView?.session.run(ARWorldTrackingConfiguration())
        self.subscription = self.arView?.scene.subscribe(to: SceneEvents.Update.self) { [unowned self] in
            onSceneUpate?($0)
        }
        self.elevationSetup()
    }
    
    /// Set the configuration for the ARView's session with options
    public func configureSession(with configuration: ARConfiguration, options: ARSession.RunOptions = []) {
        self.arView?.session.run(configuration, options: options)
    }
    
    /// Cleans up the arView which is necessary for SwiftUI navigation
    public func tearDown() {
        self.arView = nil
        self.subscription = nil
    }

    /// Adds a Entity which conforms to HasAnchoring to the arView.scene
    public func addAnchor(for entity: HasAnchoring) {
        self.arView?.scene.addAnchor(entity)
    }
    
    /// Adds an ARReferenceImage to the configuration for the session to discover
    /// Optionally can set the configuration to ARImageTrackingConfiguration
    public func addReferenceImage(for image: UIImage, _ name: String = "", with physicalWidth: CGFloat, configuration: ARConfiguration = ARWorldTrackingConfiguration()) {
        guard let referenceImage = createReferenceImage(image, name, physicalWidth) else { return }
        self.referenceImages.insert(referenceImage)
        
        if let worldConfig = configuration as? ARWorldTrackingConfiguration {
            worldConfig.detectionImages = self.referenceImages
            self.configureSession(with: worldConfig)
        } else if let imageConfig = configuration as? ARImageTrackingConfiguration {
            imageConfig.trackingImages = self.referenceImages
            self.configureSession(with: imageConfig)
        }
    }
    
    internal func createReferenceImage(_ uiImage: UIImage, _ name: String = "", _ physicalWidth: CGFloat) -> ARReferenceImage? {
        guard let cgImage = createCGImage(uiImage: uiImage) else { return nil }
        let image = ARReferenceImage(cgImage, orientation: .up, physicalWidth: physicalWidth)
        image.name = name
        return image
    }
    
    internal func createCGImage(uiImage: UIImage) -> CGImage? {
        guard let ciImage = CIImage(image: uiImage) else { return nil }
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}

extension ARManager {
    func elevationSetup() {
        let pr = UIPanGestureRecognizer(target: self, action: #selector(self.handleObjectElevation))
        pr.minimumNumberOfTouches = 2
        self.arView?.addGestureRecognizer(pr)
    }
    
    @objc func handleObjectElevation(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self.arView!)
        if gesture.state == .failed || gesture.state == .cancelled {
            return
        }

        if gesture.state == .began {
            if let rayResult = arView!.ray(through: location) {
                let results = self.arView!.scene.raycast(origin: rayResult.origin, direction: rayResult.direction)
                if let firstResult = results.first {
                    self.selectedEntity = firstResult.entity
                    self.elevation = location
                }
            }
        } else if let _ = selectedEntity {
            let deltaY = Float(location.y - self.elevation!.y) / 700
            self.selectedEntity!.position.y -= deltaY
            self.elevation = location

            if gesture.state == .ended {
                self.selectedEntity = nil
                self.elevation = nil
            }
        }
    }
}
