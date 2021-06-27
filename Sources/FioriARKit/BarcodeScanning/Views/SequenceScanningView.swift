//
//  SequenceScanningView.swift
//
//
//  Created by O'Brien, Patrick on 6/27/21.
//

import SwiftUI

public struct SequenceScanningView: View {
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            CaptureSessionContainer()
                .edgesIgnoringSafeArea(.all)
            // .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            BarcodeInfoView()
        }
    }
}

struct BarcodeInfoView: View {
    var body: some View {
        HStack {
            Text("Payload: 39393920")
                .font(.system(size: 24))
                .foregroundColor(.black)
                .padding(.leading, 10)
        }
        .frame(width: UIScreen.main.bounds.width, height: 50, alignment: .leading)
        .background(Color.white)
    }
}
