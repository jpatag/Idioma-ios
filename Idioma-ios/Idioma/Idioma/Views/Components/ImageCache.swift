//
//  ImageCache.swift
//  Idioma
//
//  Singleton wrapper around NSCache for storing UIImages.
//

import UIKit

class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        // Set limits if needed, e.g., cache.countLimit = 100
        // Or byte limit
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
}
