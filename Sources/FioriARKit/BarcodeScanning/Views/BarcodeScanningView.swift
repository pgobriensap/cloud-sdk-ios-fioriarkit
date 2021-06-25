//
//  BarcodeScanningView.swift
//
//
//  Created by O'Brien, Patrick on 6/24/21.
//

import SwiftUI

public struct BarcodeScanningView: View {
    /// arModel
    @ObservedObject public var barcodeModel: BarcodeScanningViewModel
    
    public var body: some View {
        ZStack {
            ARContainer(arStorage: barcodeModel.arManager)
        }
        .edgesIgnoringSafeArea(.all)
        .navigationBarTitle("")
        .navigationBarHidden(true)
        .overlay(DismissButton().opacity(Double(0.8)), alignment: .topLeading)
    }
    
    private struct DismissButton: View {
        @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
        
        var body: some View {
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }, label: {
                Text(Image(systemName: "xmark"))
                    .fontWeight(.light)
                    .font(.system(.title2))
                    .font(.system(size: 19))
                    .frame(width: 44, height: 44)
                    .foregroundColor(Color.preferredColor(.primaryLabel, background: .darkConstant))
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(Color.black.opacity(0.6))
                    )
            })
                .padding([.leading, .top], 16)
        }
    }
}
