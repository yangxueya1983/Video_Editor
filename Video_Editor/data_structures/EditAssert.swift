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
    let cacheDir: String
    var asset: AVAsset?
    var selectTimeRange: CMTimeRange = .zero
    var maxDuration: CMTime = .zero
    
    init(cacheDir: String) {
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
    
    func preprocess() -> Bool {
        return true
    }
//    
//    func getLength(timeScale: Float, timeScaleLen: Float) -> CGFloat {
//        let seconds = selectTimeRange.duration.seconds
//        return seconds / CGFloat(timeScale) * CGFloat(timeScaleLen)
//    }
}

class VisualEditAsset: EditAsset {
    func getThumnaisls(cnt: Int) -> [UIImage?] {
        assert(false , "subclass should override this method")
        let ret = [UIImage]()
        return ret
    }
}

class AudioEditAsset: EditAsset {
    
}

class PhotoEditAsset : VisualEditAsset {
    var thumnail: UIImage?
    var representImage: UIImage?
    var origImage: UIImage?
    
    private var processed = false
    
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
    
    init(image: UIImage, cacheDir: String) {
        super.init(cacheDir: cacheDir)
        self.origImage = image
    }
    
    override func getCacheAssetPath() -> String {
        return cacheDir + "/video.mov"
    }
    
    override func process() async -> Bool {
        if processed == true {
            return true
        }
        
        processed = true
        return await generateFileDataFromLocal()
    }
    
    override func preprocess() -> Bool {
        // TODO: implement for the photo library
        return true
    }
    
    override func getThumnaisls(cnt: Int) -> [UIImage?] {
        var ret = [UIImage?]()
        for _ in 0..<cnt {
            ret.append(thumnail)
        }
        
        return ret
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
        
        print("generate video at url \(targetUrl.path)")
        
        return true
    }
    
    private func generateFileDataFromLocal() async -> Bool {
        // TODO: what if the original image is not portrait
        guard let originalImg = origImage else {
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
    

}

class VideoEditAsset: VisualEditAsset {
    // don't need this one if for photo -> video only
}
