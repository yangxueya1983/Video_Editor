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
    static let archivePropertyPath = "archiveProperty.json"
}

enum EditType : Int {
    case Unknown, Audio, Video, Image
}


struct AssetProperty : Codable {
    let type : EditType
    let selectRangeStart : Double
    let selectRangeEnd : Double
    let maxDuration: Double
    
    // Custom coding keys to rename properties in JSON
    enum CodingKeys: String, CodingKey {
        case type
        case rangeStart
        case rangeEnd
        case duration
    }
    
    // Encode the struct to JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(selectRangeStart, forKey: .rangeStart)
        try container.encode(selectRangeEnd, forKey: .rangeEnd)
        try container.encode(maxDuration, forKey: .duration)
    }
    
    init(type: EditType, selectRangeStart: Double, selectRangeEnd: Double, maxDuration: Double) {
        self.type = type
        self.selectRangeStart = selectRangeStart
        self.selectRangeEnd = selectRangeEnd
        self.maxDuration = maxDuration
    }
    
    // Decode the struct from JSON
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let t = try container.decode(Int.self, forKey: .type)
        type = EditType(rawValue: t)!
        
        selectRangeStart = try container.decode(Double.self, forKey: .rangeStart)
        selectRangeEnd = try container.decode(Double.self, forKey: .rangeEnd)
        maxDuration = try container.decode(Double.self, forKey: .duration)
    }
}

class EditAsset {
    let id = UUID()
    let cacheDir: String
    var asset: AVAsset?
    var selectTimeRange: CMTimeRange = .zero
    var maxDuration: CMTime = .zero
    

    
    var editType: EditType = .Unknown
    
    // for create new asset
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
    
    init(fromArchiveDir: String) {
        cacheDir = fromArchiveDir
    }
    
    func process() async -> Bool {
        return true
    }
    
    func saveProperty() -> Bool {
        assert(false, "subclass should override this method")
        return false
    }
    
    func getCacheAssetPath() -> String {
        assert(false, "subclass should override this method")
        return ""
    }
    
    func preprocess() -> Bool {
        return true
    }
    
    func getEstimatedSize() -> Int {
        assert(false, "subclass should override this method")
        return 0
    }
}

class VisualEditAsset: EditAsset {
    func getThumnaisls(cnt: Int) -> [UIImage?] {
        assert(false , "subclass should override this method")
        let ret = [UIImage]()
        return ret
    }
    
    func generateAssetForSize(size: CGSize) async throws -> AVAsset? {
        assert(false , "subclass should override this method")
        return nil
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
    
    override init(fromArchiveDir: String) {
        super.init(fromArchiveDir: fromArchiveDir)
        
        // load images
        thumnail = UIImage(contentsOfFile: thummnailPath)
        representImage = UIImage(contentsOfFile: representImgPath)
        origImage = UIImage(contentsOfFile: origImgPath)
    }
    
    override func getCacheAssetPath() -> String {
        return "video.mov"
    }
    
    override func process() async -> Bool {
        if processed == true {
            return true
        }
        
        processed = true
        if await !generateFileDataFromLocal() {
            return false
        }
        
        if !saveProperty() {
            return false
        }
        
        return true
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
    
    override func generateAssetForSize(size: CGSize) async throws -> AVAsset? {
        guard processed, let origImage = origImage else {
            assert(false, "process() should be called before this method")
            return nil
        }

        if size.width < 1024 && size.height < 768 {
            // use the original asset since it is generated by using 1024 x 768
            return asset
        }
        
        let outputURL = URL(fileURLWithPath: cacheDir + "/export_video.mov")
        let error = try await PhotoMediaUtility.createVideoFromImage(image: origImage, videoSize: size, duration: CMTime(seconds: 5, preferredTimescale: 1000), outputURL: outputURL)
        if let error {
            print("generate export video failed for error: \(error)")
            return nil
        }
        
        asset = AVURLAsset(url: outputURL)
        return asset
    }
    
    override func getEstimatedSize() -> Int {
        assert(processed, "call estimated size without processed")
        
        let path = cacheDir + "/" + getCacheAssetPath()
        if FileManager.default.fileExists(atPath: path) {
            return try! FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0
        }
        
        return 0
    }
    
    override func saveProperty() -> Bool {
        // save json file
        let savePath = cacheDir + "/" + AssetConfig.archivePropertyPath
        
        let assetProperty = AssetProperty(type: EditType.Image, selectRangeStart: selectTimeRange.start.seconds, selectRangeEnd: selectTimeRange.end.seconds, maxDuration: maxDuration.seconds)
        
        do {
            if FileManager.default.fileExists(atPath: savePath) {
                try FileManager.default.removeItem(atPath: savePath)
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(assetProperty).write(to: URL(filePath: savePath))
        } catch {
            print("save property failed for error: \(error)")
            return false
        }
        
        return true
    }
    
    private func generateVideo(image: UIImage?) async -> Bool {
        guard let image = image else {
            return false
        }
        
        let targetUrl = URL(fileURLWithPath: cacheDir + "/" + getCacheAssetPath())
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

struct EditAssetArchiveLoader {
    static func load(dir: String) -> EditAsset? {
        let propertyFile = dir + "/" + AssetConfig.archivePropertyPath
        // sanity check
        guard let lastComponent = dir.split(separator: "/").last, lastComponent.contains(EditProject.assetDirPrefix) else {
            return nil
        }
        
        // load the properites
        var assetProperty: AssetProperty?
        do {
            let readData = try Data(contentsOf: URL(fileURLWithPath: propertyFile))
            
            let decoder = JSONDecoder()
            assetProperty = try decoder.decode(AssetProperty.self, from: readData)
        } catch {
            print("load the property json failed")
        }
        
        guard let assetProperty, assetProperty.type != .Unknown else {
            return nil
        }
        
        switch assetProperty.type {
        case .Image:
            var imageAsset = PhotoEditAsset(fromArchiveDir: dir)
            imageAsset.maxDuration = CMTime(seconds: assetProperty.maxDuration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            imageAsset.selectTimeRange = CMTimeRange(start: CMTime(seconds: assetProperty.selectRangeStart, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), end: CMTime(seconds: assetProperty.selectRangeEnd, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
            
            return imageAsset
        default:
            assert(false, "not supported asset type: \(assetProperty.type)")
        }
        
        return nil
    }
}
