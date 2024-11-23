//
//  EditProject.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation
import AVFoundation

class EditProject {
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
        
        assert(!FileManager.default.fileExists(atPath: dir), "directory already exists")
        
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        } catch {
            print("failed to create directory with error: \(error.localizedDescription)")
        }
    }
    
    func getNextAssetDirectory() -> String? {
        var asset_idx = 0
        let prefix = "Asset"
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
        let transitionDuration = CMTime(value: 5, timescale: 10)
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
            frameDuration: frameRate) else {
            return false
        }
        
        composition = mixComp
        videoComposition = videoComp
        videoDuration = duration
        
        print("create the composition asset with total duration \(duration.seconds)")
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
    
    func export(to url: URL) async throws -> Bool {
        guard let asset = composition else {
            print("Error: asset is not ready")
            return false
        }
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            print("Error: export ession create failed")
            return false
        }
        
        exportSession.outputURL = url
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
        
        await exportSession.export()
        switch exportSession.status {
        case .completed:
            return true
        default:
            print("export error : \(exportSession.error?.localizedDescription ?? "")")
            return false
        }
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
}

class ProjectManager {
    static let sharedMgr : ProjectManager = ProjectManager()
    
    func getNextProjectDir() -> String? {
        let userDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
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
    
    func loadEditProject() -> [EditProject] {
        let ret: [EditProject] = []
        return ret
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
