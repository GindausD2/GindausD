import SwiftUI
import UIKit
import PhotosUI

// MARK: - ImageSourcePicker
//
// Shows an action sheet for choosing between Camera and Photo Library,
// then presents the appropriate picker.

struct ImageSourcePicker: View {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    @State private var showCamera: Bool = false
    @State private var showLibrary: Bool = false
    @State private var showActionSheet: Bool = false

    var body: some View {
        Color.clear
            .onAppear { showActionSheet = true }
            .confirmationDialog("Add a Photo", isPresented: $showActionSheet, titleVisibility: .visible) {
                Button("Take Photo") {
                    showCamera = true
                }
                Button("Choose from Library") {
                    showLibrary = true
                }
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
            }
            .fullScreenCover(isPresented: $showCamera, onDismiss: { if selectedImage == nil { isPresented = false } }) {
                CameraPickerView(selectedImage: $selectedImage, isPresented: $showCamera)
                    .ignoresSafeArea()
                    .onDisappear { isPresented = false }
            }
            .sheet(isPresented: $showLibrary, onDismiss: { isPresented = false }) {
                PhotoLibraryPickerView(selectedImage: $selectedImage)
            }
    }
}

// MARK: - Camera Picker (UIImagePickerController)

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let img = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.selectedImage = img
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Photo Library Picker (PHPickerViewController)

struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPickerView

        init(_ parent: PhotoLibraryPickerView) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                DispatchQueue.main.async {
                    self?.parent.selectedImage = image as? UIImage
                }
            }
        }
    }
}
