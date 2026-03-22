//
//  CachedImage.swift
//  Idioma
//
//  A drop-in replacement for AsyncImage that checks ImageCache first.
//

import SwiftUI

struct CachedImage<Content: View, Placeholder: View, ErrorView: View>: View {
    private let urlString: String
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    private let errorView: () -> ErrorView

    @State private var image: UIImage? = nil
    @State private var isLoading = false
    @State private var hasError = false

    init(
        url: String,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder errorView: @escaping () -> ErrorView
    ) {
        self.urlString = url
        self.content = content
        self.placeholder = placeholder
        self.errorView = errorView

        if let cached = ImageCache.shared.get(forKey: url) {
            self._image = State(initialValue: cached)
        }
    }

    var body: some View {
        Group {
            if let uiImage = image {
                content(Image(uiImage: uiImage))
            } else if hasError {
                errorView()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard !isLoading else { return }
        
        if let cached = ImageCache.shared.get(forKey: urlString) {
            self.image = cached
            return
        }
        
        guard let url = URL(string: urlString) else {
            self.hasError = true
            return
        }

        isLoading = true

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let downloadedImage = UIImage(data: data) {
                    ImageCache.shared.set(downloadedImage, forKey: urlString)
                    await MainActor.run {
                        self.image = downloadedImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.hasError = true
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.hasError = true
                    self.isLoading = false
                }
            }
        }
    }
}
