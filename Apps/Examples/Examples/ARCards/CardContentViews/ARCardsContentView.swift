//
//  ARCardsDefaultContentView.swift
//  Examples
//
//  Created by O'Brien, Patrick on 5/5/21.
//

import FioriARKit
import SwiftUI

struct ARCardsDefaultContentView: View {
    @StateObject var arModel = ARAnnotationViewModel<StringIdentifyingCardItem>()
    @State var image: Image? = nil
    
    var body: some View {
        SingleImageARCardView(arModel: arModel,
                              image: $image,
                              cardAction: { id in
                                  // set the card action for id corresponding to the CardItemModel
                                  print(id)
                              })
            .onAppear(perform: loadInitialData)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    image = Image("qrImage")
                }
            }
    }
    
    func loadInitialData() {
        let cardItems = Tests.carEngineCardItems
        guard let anchorImage = UIImage(named: "qrImage") else { return }
        let strategy = RCProjectStrategy(cardContents: cardItems, anchorImage: anchorImage, physicalWidth: 0.1, rcFile: "ExampleRC", rcScene: "ExampleScene")
        arModel.load(loadingStrategy: strategy)
    }
}
