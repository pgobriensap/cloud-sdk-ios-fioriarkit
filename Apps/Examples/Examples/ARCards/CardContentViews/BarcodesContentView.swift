//
//  CarEngineExampleContentView.swift
//  Examples
//
//  Created by O'Brien, Patrick on 5/13/21.
//

import FioriARKit
import SwiftUI

struct BarcodesContentView: View {
    @StateObject var arModel = ARAnnotationViewModel<StringIdentifyingCardItem>()
    
    var body: some View {
        SingleImageARCardView(arModel: arModel,
                              image: Image("Barcode"),
                              cardAction: { id in
                                  // set the card action for id corresponding to the CardItemModel
                                  print(id)
                              })
            .onAppear(perform: loadData)
    }
    
    func loadData() {
        let cardItems = [StringIdentifyingCardItem(id: "Barcode", title_: "Thinking In SwiftUI", icon_: Image(systemName: "barcode"))]
        guard let anchorImage = UIImage(named: "Barcode") else { return }
        let strategy = RealityComposerStrategy(cardContents: cardItems, anchorImage: anchorImage, physicalWidth: 0.05, rcFile: "BarcodeRC", rcScene: "BarcodeScene")
        arModel.load(loadingStrategy: strategy)
    }
}
