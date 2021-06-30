//
//  ARCardsDefaultContentView.swift
//  Examples
//
//  Created by O'Brien, Patrick on 5/5/21.
//

import FioriARKit
import SwiftUI

struct EditingModeContentView: View {
    @StateObject var arModel = ARAnnotationViewModel<DecodableCardItem>()
    
    var body: some View {
        SingleImageARCardView(arModel: arModel,
                              image: Image("qrImage"),
                              cardAction: { id in
                                  // set the card action for id corresponding to the CardItemModel
                                  print(id)
                              })
            .onAppear(perform: loadInitialData)
    }
    
    func loadInitialData() {
        let cardItems: [DecodableCardItem] = []
        guard let anchorImage = UIImage(named: "qrImage") else { return }
        let strategy = RCProjectStrategy(cardContents: cardItems, anchorImage: anchorImage, physicalWidth: 0.1, rcFile: "EmptyRC", rcScene: "EmptyScene")
        arModel.load(loadingStrategy: strategy)
    }
}
