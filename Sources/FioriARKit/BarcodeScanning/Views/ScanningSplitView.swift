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
    @State var needBarcodes: [BarcodeModel] = [BarcodeModel(id: "0012044045893", title: "Deodorant", isDiscovered: false, symbology: .ean13),
                                               BarcodeModel(id: "9781492074533", title: "O'Reilly", isDiscovered: false, symbology: .ean13),
                                               BarcodeModel(id: "9798626292411", title: "Thinking in SwiftUI", isDiscovered: false, symbology: .ean13),
                                               BarcodeModel(id: "9780441013593", title: "Dune", isDiscovered: false, symbology: .ean13),
                                               BarcodeModel(id: "0072785103207", title: "Listerine", isDiscovered: false, symbology: .ean13),
                                               BarcodeModel(id: "B08SM59QQ7", title: "Auaua Case", isDiscovered: false, symbology: .code128),
                                               BarcodeModel(id: "http://www.auauastore.com", title: "Auana Case", isDiscovered: false, symbology: .qr)]
    
    @State var foundPayloads: Set<BarcodeModel> = []
    @State var addBarcodeSheetIsPresented = false
    
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
            
            Text("Payload: \(barcodeModel.id)")
                .padding(.trailing, 10)
        }
        .padding()
        .frame(height: 60)
    }
}

struct AddBarcodeSheet: View {
    @Binding var neededBarcodes: [BarcodeModel]
    @Binding var isPresented: Bool
    
    @State var payload = ""
    @State var title = ""
    
    @State var added: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Add Barcode")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                Spacer()
                Button("Dismiss") {
                    isPresented.toggle()
                }.font(.system(size: 17))
            }
            
            TextField("Payload...", text: $payload)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.bottom, 10)
            TextField("Title...", text: $title)
                .textFieldStyle(PlainTextFieldStyle())
            
            Button(action: {
                neededBarcodes.append(BarcodeModel(id: payload, title: title, isDiscovered: false, symbology: .ean13)) // TODO: Have user select symbology
                title = ""
                payload = ""
                added = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    added = false
                }
            }, label: {
                Text(added ? "Success!" : "Add")
                    .frame(width: 200, height: 40)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.preferredColor(.tintColor, background: .lightConstant))
                    )
            })
            
            Spacer()
        }
        .padding(20)
    }
}
