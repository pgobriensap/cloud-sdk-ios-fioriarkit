//
//  ARCardsDefaultContentView.swift
//  Examples
//
//  Created by O'Brien, Patrick on 5/5/21.
//

import FioriARKit
import SwiftUI
import UIKit

struct EditingModeContentView: View {
    var referenceImage: UIImage?
    var cardItems: [SimpleCardItem]
    var phsyicalWidth: CGFloat
    
    @StateObject var arModel = ARAnnotationViewModel<SimpleCardItem>()
    
    var body: some View {
        SingleImageARCardView(arModel: arModel,
                              image: Image(uiImage: referenceImage!),
                              cardAction: { id in
                                  // set the card action for id corresponding to the CardItemModel
                                  print(id)
                              })
            .onAppear(perform: loadInitialData)
    }
    
    func loadInitialData() {
        guard let image = referenceImage else { return }
        let strategy = ArrangedStrategy(cardContents: cardItems, anchorImage: image, physicalWidth: phsyicalWidth)
        arModel.load(loadingStrategy: strategy)
    }
}

struct AnnotationAuthoringView: View {
    @State var isPickerPresented: Bool = false
    @State var referenceImage: UIImage? = nil
    @State var cardItems: [SimpleCardItem] = []
    
    @State var title: String = ""
    @State var descriptionText: String = ""
    @State var actionText: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Reference Image:")
                    .font(.system(size: 19))
                    .padding(.leading, 15)
                Spacer()
            }
            
            imageView(for: referenceImage)
            
            VStack {
                TextField("Title...", text: $title)
                    .textFieldStyle(PlainTextFieldStyle())
                TextField("Description...", text: $descriptionText)
                    .textFieldStyle(PlainTextFieldStyle())
                TextField("Action Text...", text: $actionText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            HStack {
                Text("Cards:")
                    .font(.system(size: 19))
                    .padding(.leading, 15)
                    
                Spacer()
                
                Button(action: {
                    let detailImageName = ["Battery", "Schedule", ""].randomElement()!
                    let detailImage: Image? = detailImageName == "" ? nil : Image(detailImageName)
                    
                    let cardItem = SimpleCardItem(id: String(cardItems.count),
                                                  title_: title,
                                                  descriptionText_: descriptionText.isEmpty ? nil : descriptionText,
                                                  detailImage_: detailImage,
                                                  actionText_: actionText.isEmpty ? nil : actionText,
                                                  icon_: Image(systemName: ["arkit", "play.fill", "info", "display"].randomElement()!))
                    
                    self.cardItems.append(cardItem)
                    
                    title = ""
                    descriptionText = ""
                    actionText = ""
                    
                }, label: {
                    Text("Add")
                        .font(.system(size: 19))
                        .foregroundColor(Color.white)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                                .frame(width: 100, height: 45)
                        )
                })
                    .padding(.trailing, 50)
            }.padding(.bottom, 10)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 15) {
                    ForEach(cardItems) { cardItem in
                        CardView(model: cardItem, isSelected: true, action: nil)
                    }
                }
            }
        }
        .toolbar {
            NavigationLink(destination: EditingModeContentView(referenceImage: referenceImage, cardItems: cardItems, phsyicalWidth: 0.1), label: {
                Text("Publish")
            })
        }
        .sheet(isPresented: $isPickerPresented) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $referenceImage, cancel: $isPickerPresented)
        }
    }
    
    @ViewBuilder
    func imageView(for image: UIImage?) -> some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 150)
        } else {
            VStack(spacing: 20) {
                Text("No image selected")
                    .font(.system(size: 24))
                Button(action: {
                    isPickerPresented.toggle()
                }, label: {
                    Text("Pick Image")
                        .font(.system(size: 19))
                        .foregroundColor(Color.white)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                                .frame(width: 120, height: 45)
                        )
                })
            }
            .padding(40)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [15]))
                    .foregroundColor(Color.white)
            )
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIImagePickerController
    typealias SourceType = UIImagePickerController.SourceType

    let sourceType: SourceType
    @Binding var selectedImage: UIImage?
    @Binding var cancel: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let viewController = UIImagePickerController()
        viewController.delegate = context.coordinator
        viewController.sourceType = self.sourceType
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker
        
        init(_ imagePicker: ImagePicker) {
            self.parent = imagePicker
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image: UIImage? = {
                if let image = info[.editedImage] as? UIImage {
                    return image
                }
                return info[.originalImage] as? UIImage
            }()
            parent.selectedImage = image
            self.parent.cancel.toggle()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.parent.cancel.toggle()
        }
    }
}
