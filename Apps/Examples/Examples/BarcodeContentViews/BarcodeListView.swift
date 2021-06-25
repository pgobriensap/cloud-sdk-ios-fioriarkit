//
//  ContentView.swift
//  Examples
//
//  Created by O'Brien, Patrick on 5/5/21.
//

import SwiftUI

struct BarcodeListView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: ARCardsDefaultContentView()) {
                    Text("Fast Sequence")
                }
                
                NavigationLink(destination: ARCardsDefaultContentView()) {
                    Text("Batch Scanning")
                }
                
                NavigationLink(destination: ARCardsDefaultContentView()) {
                    Text("Split View")
                }
                
            }.navigationBarTitle("Examples")
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
