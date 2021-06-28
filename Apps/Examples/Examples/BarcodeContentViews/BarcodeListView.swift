//
//  ContentView.swift
//  Examples
//
//  Created by O'Brien, Patrick on 5/5/21.
//

import FioriARKit
import SwiftUI

struct BarcodeListView: View {
    var body: some View {
        List {
            NavigationLink(destination: SequenceScanningView()) {
                Text("Fast/Batch Scanning")
            }
            
            NavigationLink(destination: ScanningSplitView()) {
                Text("Needed Barcodes")
            }
        }.navigationBarTitle("Examples")
    }
}
