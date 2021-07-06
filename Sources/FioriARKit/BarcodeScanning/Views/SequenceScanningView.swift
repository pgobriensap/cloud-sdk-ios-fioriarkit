//
//  SequenceScanningView.swift
//
//
//  Created by O'Brien, Patrick on 6/27/21.
//

import SwiftUI

public struct SequenceScanningView: View {
    @State var currentPayload: BarcodeModel = .empty
    @State var discoveredPayloads: Set<BarcodeModel> = []
    @State var neededBarcodes: [BarcodeModel] = []
    @State var isTotalPayloadsPresented = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            CaptureSessionContainer(currentPayload: $currentPayload, discoveredPayloads: $discoveredPayloads, neededBarcodes: $neededBarcodes)
                .edgesIgnoringSafeArea(.all)
            BarcodeInfoView(currentPayload: $currentPayload, isTotalPayloadsPresented: $isTotalPayloadsPresented)
        }
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $isTotalPayloadsPresented) {
            BarcodeSheet(isPresented: $isTotalPayloadsPresented, discoveredPayloads: $discoveredPayloads)
        }
    }
}

struct BarcodeInfoView: View {
    @Binding var currentPayload: BarcodeModel
    @Binding var isTotalPayloadsPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SCANNED")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                
                Spacer()
                
                Button("List") {
                    isTotalPayloadsPresented.toggle()
                }
                .font(.system(size: 20))
                .foregroundColor(.blue)
            }.padding([.leading, .top, .trailing], 15)
            
            Text("\(currentPayload.symbologyString) \(currentPayload.id)")
                .font(.system(size: 17))
                .foregroundColor(.white)
                .padding(.leading, 15)
            
            Spacer()
        }
        .frame(width: UIScreen.main.bounds.width, height: 115)
        .background(Color.black.opacity(0.8))
    }
}

struct BarcodeSheet: View {
    @Binding var isPresented: Bool
    @Binding var discoveredPayloads: Set<BarcodeModel>
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Previous Barcodes")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                Spacer()
                Button("Dismiss") {
                    isPresented.toggle()
                }.font(.system(size: 17))
            }
            .padding(20)
            
            List {
                ForEach(Array(discoveredPayloads), id: \.self) { payload in
                    HStack(spacing: 20) {
                        Text(payload.id)
                        Text(payload.symbologyString)
                    }
                }
            }
        }
    }
}
