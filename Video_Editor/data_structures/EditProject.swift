//
//  EditProject.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation
import UIKit
import AVFoundation

class ExportConfig {
    enum ExportResolution : Int {
        case R480 = 0, R720 = 1, R1080 = 2, R2K = 3, R4K = 4
    }
    
    enum FrameRate {
        case FR24, FR25, FR30, FR50, FR60
    }
    
    enum BitRate {
        case Low, Recommended, High
    }
    
    var resolution: ExportResolution = .R1080
    var frameRate: FrameRate = .FR60
    var bitRate: BitRate = .Recommended
}

// lightweight class used
class PreviewProject {
    let _dir: String
    let _createDate: Date
    let _modifyDate: Date
    var _videoEstimateSize: Int64 = 0
    var _videoDuration: Double = 0
    var _thumnail: UIImage?
    
    init(dir: String) {
        _dir = dir
        
        // the dir must be exists
        guard FileManager.default.fileExists(atPath: dir) else {
            assert(false, "the dir \(dir) does not exist")
        }
        
        let attribute = try! FileManager.default.attributesOfItem(atPath: dir)
        _createDate = attribute[.creationDate] as! Date
        _modifyDate = attribute[.modificationDate] as! Date
        
        print("project dir: \(dir) created at \(_createDate), modified at \(_modifyDate)")
        
        let propertiesFile = dir.appending("/\(EditProject.propertyJsonFileName)")
        guard FileManager.default.fileExists(atPath: propertiesFile) else {
            print("no property file found at \(propertiesFile)")
            return
        }
        
        do {
            let data = try! Data(contentsOf: URL(fileURLWithPath: propertiesFile))
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                _videoEstimateSize = json[EditProject.propertySizeKey] as? Int64 ?? 0
                _videoDuration = json[EditProject.propertyDurationKey] as? Double ?? 0.0
                if let thumnailPath = json[EditProject.propertyThumnailKey] as? String {
                    _thumnail = UIImage(contentsOfFile: _dir + "/" + thumnailPath)
                }
            }
        } catch {
            print("error reading property file: \(error.localizedDescription)")
        }
    }
    
    func getArchivedProject() -> EditProject? {
        let result = EditProject(dir: _dir)
        return result
    }
}

struct PropjectProperty : Codable {
    let visualAssetPaths: [String]
    let audioAssetPaths: [String]
    let transitions: [VideoTransition]
    
    enum CodingKeys: String, CodingKey {
        case visualAssetPaths = "visualAssets"
        case audioAssetPaths = "audioAssets"
        case transitions = "transitions"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(visualAssetPaths, forKey: .visualAssetPaths)
        try container.encode(audioAssetPaths, forKey: .audioAssetPaths)
        try container.encode(transitions, forKey: .transitions)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        visualAssetPaths = try container.decode([String].self, forKey: .visualAssetPaths)
        audioAssetPaths = try container.decode([String].self, forKey: .audioAssetPaths)
        transitions = try container.decode([VideoTransition].self, forKey: .transitions)
    }
}

class EditProject {
    // save size, duration, thumbnail
    static let propertyJsonFileName = "property.json"
    static let propertySizeKey = "size"
    static let propertyDurationKey = "duration"
    static let propertyThumnailKey = "thumbnail"
    static let assetDirPrefix = "asset"
    
    private let projectID: UUID

    // include video asset photo asset
    public private(set) var visualAssets : [VisualEditAsset] = []
    // audio assets
    public private(set) var audioAssets: [AudioEditAsset] = []
    // transitions between visual assets
    public private(set) var transitions: [VideoTransition] = []

    private var id2AssetMap: [UUID: EditAsset] = [:]
    
    public private(set) var composition: AVMutableComposition?
    public private(set) var videoComposition: AVMutableVideoComposition?
    
    var isReady: Bool {
        return composition != nil && videoComposition != nil
    }
    
    var videoDuration: CMTime?
    // the directory where the project is
    private let dir: String

    init(dir: String) {
        projectID = UUID()
        self.dir = dir
        
        if (!FileManager.default.fileExists(atPath: dir)) {
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            } catch {
                print("failed to create directory with error: \(error.localizedDescription)")
            }
        } else {
            // it is archived project
            let enumarator = FileManager.default.enumerator(atPath: dir)
            if let allAssetDirs = enumarator?.allObjects as? [String] {
                let assetDirs = allAssetDirs.filter({ $0.contains(EditProject.assetDirPrefix)})
                print("find assetDirs: \(assetDirs)")
                
                for assetDir in assetDirs {
                    guard let asset = EditAssetArchiveLoader.load(dir: assetDir) else {
                        continue
                    }
                    if asset.editType == .Video || asset.editType == .Image {
                        visualAssets.append(asset as! VisualEditAsset)
                    } else {
                        assert(asset.editType == .Audio)
                        audioAssets.append(asset as! AudioEditAsset)
                    }
                }
            }
            
        }
    }
    
    func getNextAssetDirectory() -> String? {
        var asset_idx = 0
        let prefix = EditProject.assetDirPrefix
        while true {
            let fullPath = dir + "/" + prefix + "_\(asset_idx)"
            if !FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
            asset_idx += 1
        }
        
        return nil
    }
    
    /// create the composition after project update
    /// - Returns: (compisition, videoComposition)?
    func createCompositionAsset() async throws -> Bool {
        guard try await prepareAssets() else {
            return false
        }
        
        let assets = visualAssets.map(\.asset!)
        let selectRanges = visualAssets.map(\.selectTimeRange)
        let transitions = transitions.map(\.type)
        // 0.5 seconds
        let transitionDuration = EditorSetting.transitionTime
        let videoSize = CGSizeMake(1024, 768)
        let frameRate = CMTime(value: 1, timescale: 60)
        
        guard let (mixComp, videoComp, duration) = try await TransitionUtility.configureMixComposition(
            videoAssets: assets,
            videoRanges: selectRanges,
            transitions: transitions,
            audioAssets: [],
            audioRanges: [],
            audioInsertTimes: [],
            transitionDuration: transitionDuration,
            videoSie: videoSize,
            frameDuration: frameRate,
            customComposeClass: PlaybackCustomVideoCompositor.self) else {
            return false
        }
        
        composition = mixComp
        videoComposition = videoComp
        videoDuration = duration
        
        // need to reset the instructions so the player can use instructions to do the transitions
        var instructions = [AVMutableVideoCompositionInstruction]()
        for inst in videoComposition!.instructions {
            instructions.append(inst as! AVMutableVideoCompositionInstruction)
        }
        InstructionStore.shared.instructions = instructions
        
        print("create the composition asset with total duration \(duration.seconds)")
        
        if !saveProjectProperties() {
            return false
        }
        
        return true
    }

    func swapAsset(_ idx1: Int, _ idx2: Int) async throws -> Bool {
        guard idx1 < visualAssets.count, idx2 < visualAssets.count else {
            return false
        }
        
        visualAssets.swapAt(idx1, idx2)
        if try await !createCompositionAsset() {
            return false
        }
        
        return true
    }

    func rmAsset(_ asset: EditAsset) -> Bool {
        // find index
        guard let idx = visualAssets.firstIndex(where: { a in
            a.id == asset.id
        }) else {
            return false
        }
        
        let rmObject = visualAssets.remove(at: idx)
        assert(rmObject === asset)
        
        let rmTransitionIdx = max(0, idx-1)
        assert(rmTransitionIdx < transitions.count)
        
        transitions.remove(at: rmTransitionIdx)
        return check()
    }
    
    func addVisualAsset(_ asset: VisualEditAsset) -> Bool {
        visualAssets.append(asset)
        if visualAssets.count > 1 {
            transitions.append(.init(type: .Dissolve))
        }
        
        return check()
    }

    func addAudioAsset(_ asset: AudioEditAsset) -> Bool {
        audioAssets.append(asset)
        return true
    }
    
    func export(to url: URL, config: ExportConfig = .init(), progress: ((Double) -> Void)? = nil) async throws -> Bool {
        guard let (mix, videoComp) = try await getCompositionAndVideoComposition(expConfig: config, progress: progress) else {
            print("create the composition and video composition failed")
            return false
        }

//        PhotoMediaUtility.inspectVideoPropertiesForAsset(asset: mix)
//        AVAssetExportSession.allExportPresets().forEach { print($0) }
        
        guard let exportSession = AVAssetExportSession(asset: mix, presetName: AVAssetExportPresetHighestQuality) else {
            print("Error: export ession create failed")
            return false
        }
        
        exportSession.outputURL = url
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComp
        
        await exportSession.export()
        switch exportSession.status {
        case .completed:
            return true
        default:
            print("export error : \(exportSession.error?.localizedDescription ?? "")")
            return false
        }
    }
    
    private func getCompositionAndVideoComposition(expConfig: ExportConfig, progress: ((Double) -> Void)?) async throws -> (AVComposition, AVVideoComposition)? {
        
        var renderSize : CGSize = .zero
        switch expConfig.resolution {
        case .R480:
            renderSize = CGSizeMake(640, 480)
        case .R720:
            renderSize = CGSizeMake(1280, 720)
        case .R1080:
            renderSize = CGSizeMake(1920, 1080)
        case .R2K:
            renderSize = CGSizeMake(2560, 1440)
        case .R4K:
            renderSize = CGSizeMake(3840, 2160)
        default:
            assert(false, "unkown resolution for render size")
        }
        
        var fps = 24
        switch expConfig.frameRate {
        case .FR24:
            fps = 24
        case .FR25:
            fps = 25
        case .FR30:
            fps = 30
        case .FR50:
            fps = 50
        case .FR60:
            fps = 60
        default:
            assert(false, "some framerate is not handled")
        }
        
        let frameRate = CMTimeMake(value: 1, timescale: Int32(fps))
//        if expConfig.resolution.rawValue <= 1 {
//            // the preview is already use 720p
//            guard let composition = composition, let videoComposition = videoComposition else {
//                return nil
//            }
//
//            videoComposition.frameDuration = frameRate
//            videoComposition.renderSize = renderSize
//            // set to 30% after preparing composition
//            progress?(0.3)
//            return (composition, videoComposition)
//        }
        
        // parallel execution
        var assets : [AVAsset?] = Array(repeating: nil, count: visualAssets.count)
        
        try await withThrowingTaskGroup(of: (Int, AVAsset?).self, body: { group in
            for (index, va) in visualAssets.enumerated() {
                group.addTask {
                    let asset = try await va.generateAssetForSize(size: renderSize)
                    return (index, asset)
                }
            }
            
            for try await (idx, result) in group {
                assets[idx] = result
            }
        })
        
        guard assets.allSatisfy({$0 != nil}) else {
            print("generate export video assets at least one failed")
            return nil
        }
        
        var nonOptioanalAssets : [AVAsset] = []
        for a in assets {
            nonOptioanalAssets.append(a!)
        }
        
        // 10% progress
        progress?(0.1)
        let transitionTime = EditorSetting.transitionTime
        let selectRanges = visualAssets.map(\.selectTimeRange)
        let transitions = transitions.map(\.type)
        guard let (mixComp, videoComp, duration) = try await TransitionUtility.configureMixComposition(
            videoAssets: nonOptioanalAssets,
            videoRanges: selectRanges,
            transitions: transitions,
            audioAssets: [],
            audioRanges: [],
            audioInsertTimes: [],
            transitionDuration: transitionTime,
            videoSie: renderSize,
            frameDuration: frameRate,
            customComposeClass: ExportCustomVideoCompositor.self) else {
            print("generate mix composition failed")
            return nil
        }
        
        progress?(0.3)
        
        return (mixComp, videoComp)
    }
    
    private func prepareAssets() async throws-> Bool {
        var results : [Bool] = Array(repeating: false, count: visualAssets.count)
        try await withThrowingTaskGroup(of: (Int, Bool).self, body: { group in
            for (idx,visualAsset) in visualAssets.enumerated() {
                group.addTask {
                    let ok = await visualAsset.process()
                    return (idx, ok)
                }
            }
            
            for try await (idx, result) in group {
                results[idx] = result
            }
        })
        
        return results.allSatisfy({$0 == true})
    }
    
    private func check() -> Bool {
        if !visualAssets.isEmpty && visualAssets.count - 1 != transitions.count {
            return false
        }

        return true
    }
    
    private func saveProjectProperties() -> Bool {
        guard let duration = videoDuration else { return false }
        let propertyPath = dir + "/" + EditProject.propertyJsonFileName
        
        var properties: [String: Any] = [:]
        
        var estimateSize : Int = 0
        for v in visualAssets {
            estimateSize += v.getEstimatedSize()
        }
        properties[EditProject.propertySizeKey] = estimateSize
        // get the duration
        properties[EditProject.propertyDurationKey] = duration.seconds
        
        guard let firstThumnail = visualAssets.first?.getThumnaisls(cnt: 1).first, let firstThumnail else {
            return false
        }
        
        let projectThumnailPath = dir + "/project_thumnail.png"
        properties[EditProject.propertyThumnailKey] = "project_thumnail.png"
        do {
            if FileManager.default.fileExists(atPath: projectThumnailPath) {
                try FileManager.default.removeItem(atPath: projectThumnailPath)
            }
            
            if FileManager.default.fileExists(atPath: propertyPath) {
                try FileManager.default.removeItem(atPath: propertyPath)
            }
            
            try firstThumnail.pngData()?.write(to: URL(fileURLWithPath: projectThumnailPath))
            try JSONSerialization.data(withJSONObject: properties, options: [.prettyPrinted]).write(to: URL(fileURLWithPath: propertyPath))
            
        } catch {
            print("Error saving project properties: \(error)")
            return false
        }
        
        return true
    }
}

class ProjectManager {
    static let sharedMgr : ProjectManager = ProjectManager()
    private let _userDirecotry = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    func getNextProjectDir() -> String? {
        let userDirectory = _userDirecotry
        
        var projIdx = 0
        while true {
            let projPath = userDirectory.appendingPathComponent("Projects_\(projIdx)")
            if !FileManager.default.fileExists(atPath: projPath.path) {
                return projPath.path
            }
            projIdx += 1
        }
        
        return nil
    }
    
    func loadPreviewProjects() -> [PreviewProject] {
        var ret: [PreviewProject] = []

        // enumerate the dictories
        if let urls = try? FileManager.default.contentsOfDirectory(at: _userDirecotry, includingPropertiesForKeys: [.isDirectoryKey], options: []) {
            let filterUrls = urls.filter( {$0.lastPathComponent.hasPrefix("Projects_")})
            
            // sorted by the directory create time
            let sortedUrls = filterUrls.sorted { url1, url2 in
                let attr1 = try! FileManager.default.attributesOfItem(atPath: url1.path)
                let attr2 = try! FileManager.default.attributesOfItem(atPath: url2.path)
                let date1 = attr1[.creationDate] as! Date
                let date2 = attr2[.creationDate] as! Date
                // create early item first
                return date1.timeIntervalSince1970 < date2.timeIntervalSince1970
            }
            
            for url in sortedUrls {
                let projDir = url.path
                let previewProject = PreviewProject(dir: projDir)
                ret.append(previewProject)
            }
        }

        return ret
    }
    
    func loadProjectFromPreview(preview: PreviewProject) -> EditProject? {
        let projDir = preview._dir
        let ret = EditProject(dir: projDir)
        
        // load the visual assets
        // TODO: add audio
        
        
        return nil
    }

    func ArchiveProject(_ project: EditProject) -> Bool {
        return true
    }

    private func loadVisualAsset(dir: String) -> VisualEditAsset? {
        return nil
    }

    private func loadAudioAsset(dir: String) -> AudioEditAsset? {
        return nil
    }
}
