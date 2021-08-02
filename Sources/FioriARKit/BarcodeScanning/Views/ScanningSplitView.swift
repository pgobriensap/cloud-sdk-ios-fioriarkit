//
//  ScanningSplitView.swift
//
//
//  Created by O'Brien, Patrick on 6/28/21.
//
 
import SwiftUI
import Vision

public struct ScanningSplitView: View {
    @State var currentPayload: BarcodeModel = .empty
    @State var needBarcodes: [BarcodeModel] = []
//    @State var needBarcodes: [BarcodeModel] = [BarcodeModel(id: "0012044045893", title: "Deodorant", isDiscovered: false, symbology: .ean13),
//                                               BarcodeModel(id: "9781492074533", title: "O'Reilly", isDiscovered: false, symbology: .ean13),
//                                               BarcodeModel(id: "9798626292411", title: "Thinking in SwiftUI", isDiscovered: false, symbology: .ean13),
//                                               BarcodeModel(id: "9780441013593", title: "Dune", isDiscovered: false, symbology: .ean13),
//                                               BarcodeModel(id: "0072785103207", title: "Listerine", isDiscovered: false, symbology: .ean13),
//                                               BarcodeModel(id: "B08SM59QQ7", title: "Auaua Case", isDiscovered: false, symbology: .code128),
//                                               BarcodeModel(id: "http://www.auauastore.com", title: "Auana Case", isDiscovered: false, symbology: .qr)]
    
    @State var foundPayloads: Set<BarcodeModel> = []
    @State var addBarcodeSheetIsPresented = false
    @State var startSession: (() -> Void)? = nil
    @State var stopSession: (() -> Void)? = nil
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            CaptureSessionContainer(currentPayload: $currentPayload, discoveredPayloads: $foundPayloads, neededBarcodes: $needBarcodes)
                .edgesIgnoringSafeArea(.all)
            BottomDrawer(neededBarcodes: $needBarcodes)
        }
        .toolbar {
            Button("Add Barcode") {
                addBarcodeSheetIsPresented.toggle()
            }
        }
        .sheet(isPresented: $addBarcodeSheetIsPresented) {
            AddBarcodeSheet(neededBarcodes: $needBarcodes, isPresented: $addBarcodeSheetIsPresented)
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
                }.onDelete(perform: deleteRow)
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: 300)
        .background(Color.black)
        .cornerRadius(8)
        .offset(y: isOffsetHidden ? 200 : 0)
    }
    
    func deleteRow(at offsets: IndexSet) {
        self.neededBarcodes.remove(atOffsets: offsets)
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
            
            Text("\(barcodeModel.symbologyString) \(barcodeModel.id)")
                .padding(.trailing, 10)
        }
        .padding()
        .frame(height: 60)
    }
}

struct AddBarcodeSheet: View {
    @Binding var neededBarcodes: [BarcodeModel]
    @Binding var isPresented: Bool
    
    @State var currentPayload: BarcodeModel = .empty
    @State var needBarcodes: [BarcodeModel] = []
    @State var foundPayloads: Set<BarcodeModel> = []
    @State var title = ""
    @State var added: Bool = false
    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    Button("Dismiss") {
                        isPresented.toggle()
                    }
                    Spacer()
                    Button(action: {
                        if currentPayload != .empty {
                            neededBarcodes.append(BarcodeModel(id: currentPayload.id, title: title.isEmpty ? "Title Unknown" : title, isDiscovered: false, symbology: currentPayload.symbology))
                        }
                        title = ""
                        currentPayload = .empty
                        added = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            added = false
                        }
                    }, label: {
                        Text(added ? "Success!" : "Add Barcode")
                    })
                }.padding()
                
                VStack {
                    HStack {
                        Text("Title:")
                        TextField("Add Title...", text: $title)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    HStack {
                        Text("Payload:")
                        Text(currentPayload.id)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding()
            }
            
            CaptureSessionContainer(currentPayload: $currentPayload, discoveredPayloads: $foundPayloads, neededBarcodes: $needBarcodes)
                .padding()
                .ignoresSafeArea(.keyboard)
        }
    }
}
