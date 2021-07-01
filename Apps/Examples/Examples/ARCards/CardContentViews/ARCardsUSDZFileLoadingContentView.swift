//
//  ARCardsUSDZFileLoadingContentView.swift
//  Examples
//
//  Created by O'Brien, Patrick on 6/22/21.
//

import FioriARKit
import SwiftUI
import Zip

struct ARCardsUSDZFileLoadingContentView: View {
    @StateObject var arModel = ARAnnotationViewModel<DecodableCardItem>()
    
    var body: some View {
        SingleImageARCardView(arModel: arModel,
                              image: Image("qrImage"),
                              cardAction: { id in
                                  // set the card action for id corresponding to the CardItemModel
                                  print(id)
                              })
            .onAppear(perform: loadInitialDataFromUSDZFile)
    }

    func loadInitialDataFromUSDZFile() {
        let usdzFilePath = FileManager.default.getDocumentsDirectory().appendingPathComponent(FileManager.usdzFiles).appendingPathComponent("ExampleRC.usdz")
        let dirFile = FileManager.default.getDocumentsDirectory().appendingPathComponent(FileManager.usdzFiles).appendingPathComponent("ExampleDir.zip")
        guard let absoluteUsdzPath = URL(string: "file://" + usdzFilePath.path),
              let absoluteZipPath = URL(string: "file://" + dirFile.path),
              let jsonUrl = Bundle.main.url(forResource: "Tests", withExtension: "json") else { return }
        
        do {
            let unzippedUsdz = try Zip.quickUnzipFile(absoluteZipPath)
            let imageFolder = unzippedUsdz.appendingPathComponent("0")
            let items = try FileManager.default.contentsOfDirectory(atPath: imageFolder.path)
            let imagePath = imageFolder.appendingPathComponent(items.first!)
            
            let anchorImage = UIImage(contentsOfFile: imagePath.path)
            
            let jsonData = try Data(contentsOf: jsonUrl)
            let strategy = try UsdzFileStrategy(jsonData: jsonData, physicalWidth: 0.1, usdzFilePath: absoluteUsdzPath)
            arModel.load(loadingStrategy: strategy)
        } catch {
            print(error)
        }
    }
}
