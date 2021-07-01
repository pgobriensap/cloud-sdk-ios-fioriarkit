//
//  AddAnnotationView.swift
//
//
//  Created by O'Brien, Patrick on 7/1/21.
//

import SwiftUI

internal struct AddAnnotationView: View {
    @Binding var isPresented: Bool
    var addAnnotation: ((String, String, String, String) -> Void)?
    
    internal init(isPresented: Binding<Bool>, addAnnotation: ((String, String, String, String) -> Void)?) {
        self._isPresented = isPresented
        self.addAnnotation = addAnnotation
    }
    
    @State var title: String = ""
    @State var descriptionText: String = ""
    @State var actionText: String = ""
    @State var selectedIndex = 0
    
    private var availableIcons = ["info", "doc.fill", "play", "link"]

    var body: some View {
        VStack(spacing: 10) {
            ModalHeaderView(isPresented: $isPresented, title: "Add Annotation")
            
            TextField("Title...", text: $title)
                .textFieldStyle(PlainTextFieldStyle())
            TextField("Description...", text: $descriptionText)
                .textFieldStyle(PlainTextFieldStyle())
            TextField("Action Text...", text: $actionText)
                .textFieldStyle(PlainTextFieldStyle())
            
            Picker("Favorite Color", selection: $selectedIndex, content: {
                ForEach(0 ..< availableIcons.count, content: { index in
                    Image(systemName: availableIcons[index])
                })
            })
            
            Button(action: {
                addAnnotation?(title, descriptionText, actionText, availableIcons[selectedIndex])
                isPresented.toggle()
            }, label: {
                Text("Add")
                    .frame(width: 200, height: 40)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.preferredColor(.tintColor, background: .lightConstant))
                    )
            })
            
            Spacer()
        }.padding()
    }
}

struct ModalHeaderView: View {
    @Binding var isPresented: Bool
    
    var title: String
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22))
                .padding(.leading, 15)
            
            Spacer()
            
            Button("Dismiss") {
                isPresented.toggle()
                onDismiss?()
            }
            .font(.system(size: 22))
        }
        .frame(maxWidth: .infinity, maxHeight: 50)
    }
}
