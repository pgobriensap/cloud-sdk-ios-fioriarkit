//
//  SwiftUIView.swift
//
//
//  Created by O'Brien, Patrick on 6/14/21.
//

import SwiftUI
import Vision

struct BarcodeList: View {
    @Binding var neededBarcodes: [BarcodeModel]
    
    var body: some View {
        List {
            ForEach(neededBarcodes) { barcode in
                
                BarcodeRowView(title: barcode.title, exists: barcode.discovered)
            }
        }
    }
}

struct BarcodeModel: Identifiable {
    public init(id: String, title: String, discovered: Bool, position: CGPoint? = nil, size: CGSize? = nil, symbology: VNBarcodeSymbology?) {
        self.id = id
        self.title = title
        self.discovered = discovered
        self.position = position
        self.size = size
        self.symbology = symbology
    }
    
    var id: String
    var title: String
    var discovered: Bool
    var position: CGPoint?
    var size: CGSize?
    var symbology: VNBarcodeSymbology?
}

struct BarcodeRowView: View {
    var title: String
    var exists: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(Color.white)
                .padding(.leading, 10)
            
            Spacer()
            
            Text(exists ? "Found!" : "Not Found")
            
            Image(systemName: exists ? "checkmark.circle.fill" : "questionmark.circle.fill")
                .foregroundColor(exists ? Color.green : Color.yellow)
                .padding(.trailing, 10)
        }
        .font(.system(size: 19))
        .frame(height: 40)
    }
}
