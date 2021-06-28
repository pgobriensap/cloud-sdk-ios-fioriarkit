//
//  ScanningSplitView.swift
//
//
//  Created by O'Brien, Patrick on 6/28/21.
//

import SwiftUI
import Vision

public struct ScanningSplitView: View {
    @State var currentPayload: String = ""
    @State var needBarcodes: [BarcodeModel] = [BarcodeModel(id: "0012044045893", title: "Deodorant", isDiscovered: false, symbology: .EAN13),
                                               BarcodeModel(id: "9781492074533", title: "O'Reilly", isDiscovered: false, symbology: .EAN13),
                                               BarcodeModel(id: "9798626292411", title: "Thinking in SwiftUI", isDiscovered: false, symbology: .EAN13),
                                               BarcodeModel(id: "9780441013593", title: "Dune", isDiscovered: false, symbology: .EAN13),
                                               BarcodeModel(id: "0072785103207", title: "Listerine", isDiscovered: false, symbology: .EAN13)]
    
    @State var foundPayloads: Set<String> = []
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            CaptureSessionContainer(currentPayload: $currentPayload, discoveredPayloads: $foundPayloads, neededBarcodes: $needBarcodes)
                .edgesIgnoringSafeArea(.all)
            BottomDrawer(neededBarcodes: $needBarcodes)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct BottomDrawer: View {
    @Binding var neededBarcodes: [BarcodeModel]
    @State var isOffsetHidden: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Needed Barcodes")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .padding(.top, 5)
                
                Spacer()
                
                Button(isOffsetHidden ? "Expand" : "Hide") {
                    withAnimation {
                        isOffsetHidden.toggle()
                    }
                }
                .font(.system(size: 22))
            }
            .padding(10)
            
            List {
                ForEach(neededBarcodes) { neededBarcode in
                    BarcodeRow(barcodeModel: neededBarcode)
                }
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: 300)
        .background(Color.black)
        .cornerRadius(8)
        .offset(y: isOffsetHidden ? 200 : 0)
    }
}

struct BarcodeRow: View {
    var barcodeModel: BarcodeModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(barcodeModel.title)

                Spacer()
                Image(systemName: barcodeModel.isDiscovered ? "checkmark.circle" : "questionmark.circle.fill")
                    .foregroundColor(barcodeModel.isDiscovered ? .green : .yellow)
                    .font(.system(size: 25))
            }
            
            Text("Payload: \(barcodeModel.id)")
                .padding(.trailing, 10)
        }
        .padding()
        .frame(height: 60)
    }
}

struct BarcodeModel: Identifiable {
    var id: String
    var title: String
    var isDiscovered: Bool
    var symbology: VNBarcodeSymbology
}
