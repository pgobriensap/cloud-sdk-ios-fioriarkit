//
//  SwiftUIView.swift
//
//
//  Created by O'Brien, Patrick on 6/14/21.
//

import SwiftUI

struct BarcodeList: View {
    @Binding var barcodes: [BarcodeModel]
    
    var body: some View {
        List {
            ForEach(barcodes) { barcode in
                
                BarcodeRowView(title: barcode.id, exists: barcode.exists)
            }
        }
    }
}

struct BarcodeModel: Identifiable {
    var id: String
    var payload: String
    var exists: Bool
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
