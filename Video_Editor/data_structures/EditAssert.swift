//
//  EditAssert.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation
import AVFoundation
import UIKit

struct AssetConfig {
    
}

class EditAsset {
    let id = UUID()
    let url: URL
    let cacheDir: String
    
    init(url: URL, cacheDir: String) {
        self.url = url
        self.cacheDir = cacheDir
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
    
    // in the cacahe direcotry already
    var representImgPath: String?
    var origImgPath: String?
    
    override func preprocess() -> Bool {
        // TODO: implement for the photo library
        
        return true
    }
    
    
}

class VideoEditAsset: VisualEditAsset {
    // don't need this one if for photo -> video only
}
