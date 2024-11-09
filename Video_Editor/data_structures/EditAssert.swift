//
//  EditAssert.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation
import AVFoundation
import UIKit
import Photos

struct AssetConfig {
    
}

class EditAsset {
    let id = UUID()
    let url: URL
    let cacheDir: String
    var asset: AVAsset?
    var selectTimeRange: CMTimeRange = .zero
    var maxDuration: CMTime = .zero
    
    init(url: URL, cacheDir: String) {
        self.url = url
        self.cacheDir = cacheDir
        // create the directory, remove it if not exists
        do {
            if FileManager.default.fileExists(atPath: cacheDir) {
                try FileManager.default.removeItem(atPath: cacheDir)
            }
            try FileManager.default.createDirectory(at:URL(fileURLWithPath: cacheDir), withIntermediateDirectories: true)
        } catch {
            print("remove directory error: \(error.localizedDescription)")
        }
    }
    
    func process() async -> Bool {
        return true
    }
    
    func getCacheAssetPath() -> String {
        assert(false, "subclass should override this method")
        return ""
    }
    
    func check() -> Bool {
        // TODO: not sure if it will work for photo library as well
        let fileMgr = FileManager.default
        if fileMgr.fileExists(atPath: url.path) {
            return true
        }
        
        return false
    }
    
    func preprocess() -> Bool {
        return true
    }
}

class VisualEditAsset: EditAsset {
}

class AudioEditAsset: EditAsset {
    
}

class PhotoEditAsset : VisualEditAsset {
    var thumnail: UIImage?
    var representImage: UIImage?
    
    // in the cacahe direcotry already
    var representImgPath: String {
        get { return cacheDir + "/represent_img.jpg"}
    }
    var origImgPath: String {
        get { return cacheDir + "/orig_img.jpg"}
    }
    
    var thummnailPath: String {
        get { return cacheDir + "/thumbnail.jpg"}
    }
    
    override init(url: URL, cacheDir: String) {
        super.init(url: url, cacheDir: cacheDir)
    }
    
    override func getCacheAssetPath() -> String {
        return cacheDir + "/video.mov"
    }
    
    override func process() async -> Bool {
        if url.scheme == "ph" {
            return await generateFileDataFromPHLib()
        } else {
            return await generateFileDataFromLocal()
        }
    }
    
    override func preprocess() -> Bool {
        // TODO: implement for the photo library
        return true
    }
    
    private func generateVideo(image: UIImage?) async -> Bool {
        guard let image = image else {
            return false
        }
        
        let targetUrl = URL(fileURLWithPath: getCacheAssetPath())
        do {
            let error = try await PhotoMediaUtility.createVideoFromImage(image: image, videoSize: CGSize(width: 1024, height: 768), duration: CMTime(seconds: 5, preferredTimescale: 1000), outputURL: targetUrl)
            if let error {
                print("generate video failed for error: \(error)")
                return false
            }
            
            // load the asset
            asset = AVURLAsset(url: targetUrl)
            // select time range is 5 seconds
            selectTimeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 1000))
            maxDuration = CMTime(seconds: 5, preferredTimescale: 1000)
        } catch {
            print("generate video failed for error: \(error)")
            return false
        }
        
        return true
    }
    
    private func generateFileDataFromLocal() async -> Bool {
        guard let originalImg = UIImage(contentsOfFile: url.absoluteString) else {
            print("load image from local failed for path: \(url.absoluteString)")
            return false
        }
        
        // scale down to 1024 * 1024 for represent image
        let representImg = PhotoMediaUtility.scaleImage(originalImg, toMaxSize: 1024)
        // scale down to 100 x 100 for thumnail
        let thumnailImg = PhotoMediaUtility.scaleImage(originalImg, toMaxSize: 100)
        
        guard let representImg, let thumnailImg else {
            print("scale image failed")
            return false
        }
        
        do {
            try originalImg.pngData()?.write(to: URL(fileURLWithPath: self.origImgPath))
            try representImg.pngData()?.write(to: URL(fileURLWithPath: self.representImgPath))
            try thumnailImg.pngData()?.write(to: URL(fileURLWithPath: self.thummnailPath))
        } catch {
            print("write image to cache failed: \(error)")
            return false
        }
        
        self.representImage = representImg
        self.thumnail = thumnailImg
        
        return await generateVideo(image: self.representImage)
    }
    
    private func generateFileDataFromPHLib() async -> Bool {
        // assuming it's a 'ph://' URL
        let assetID = url.lastPathComponent
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        
        guard let obj =  fetchResult.firstObject else {
            return false
        }
        
        let options: PHImageRequestOptions = .init()
        options.isSynchronous = false
        // original data format
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        let originalImage = await withCheckedContinuation { (cont) in
            PHImageManager.default().requestImage(for: obj, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { (img, _) in
                if let img {
                    cont.resume(returning: img)
                }
            }
        }

        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        // preview image
        let representImage = await withCheckedContinuation { (cont) in
            PHImageManager.default().requestImage(for: obj, targetSize: .init(width: 1024, height: 1024), contentMode: .aspectFit, options: options) { (img, _) in
                if let img {
                    cont.resume(returning: img)
                }
            }
        }
        
        // thumnail image
        let thumnaillImage = await withCheckedContinuation { (cont) in
            PHImageManager.default().requestImage(for: obj, targetSize: .init(width: 100, height: 100), contentMode: .aspectFit, options: options) { (img, _) in
                if let img {
                    cont.resume(returning: img)
                }
            }
        }
        
        // hanlding the original image, preview image and thumnail image
        do {
            try originalImage.pngData()?.write(to: .init(fileURLWithPath: self.origImgPath))
            try representImage.pngData()?.write(to: .init(fileURLWithPath: self.representImgPath))
            try thumnaillImage.pngData()?.write(to: .init(fileURLWithPath: self.thummnailPath))
        } catch {
            print("Failed to write image data to disk: \(error)")
            return false
        }
        
        self.thumnail = thumnaillImage
        self.representImage = representImage
        // the original image data is already saved to disk, will load it when used it
        // don't load it to memory to save data
        
        // generate the video from image
        return await generateVideo(image: self.representImage)
    }
}

class VideoEditAsset: VisualEditAsset {
    // don't need this one if for photo -> video only
}
