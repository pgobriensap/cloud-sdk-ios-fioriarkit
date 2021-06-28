//
//  SequenceScanningView.swift
//
//
//  Created by O'Brien, Patrick on 6/27/21.
//

import SwiftUI

public struct SequenceScanningView: View {
    @State var currentPayload = ""
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            CaptureSessionContainer(discoveredBarcode: $currentPayload)
                .edgesIgnoringSafeArea(.all)
            BarcodeInfoView(currentPayload: $currentPayload)
        }
    }
}

struct BarcodeInfoView: View {
    @Binding var currentPayload: String
    
    var body: some View {
        HStack {
            Text("Payload: \(currentPayload)")
                .font(.system(size: 24))
                .foregroundColor(.black)
                .padding(.leading, 10)
        }
        .frame(width: UIScreen.main.bounds.width, height: 50, alignment: .leading)
        .background(Color.white)
    }
}
