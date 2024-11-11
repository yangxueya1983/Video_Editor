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
    private var visualAssets : [VisualEditAsset] = []
    // audio assets
    private var audioAssets: [AudioEditAsset] = []
    // transitions between visual assets
    private var transitions: [VideoTransition] = []

    private var id2AssetMap: [UUID: EditAsset] = [:]
    
    private var composition: AVMutableComposition?
    private var videoComposition: AVMutableVideoComposition?
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
    func createCompositionAsset() async throws -> (AVMutableComposition, AVMutableVideoComposition)? {
        let assets = visualAssets.map(\.asset!)
        let selectRanges = visualAssets.map(\.selectTimeRange)
        let transitions = transitions.map(\.type)
        // 0.5 seconds
        let transitionDuration = CMTime(value: 5, timescale: 10)
        let videoSize = CGSizeMake(1024, 768)
        let frameRate = CMTime(value: 1, timescale: 60)
        
        guard let (mixComp, videoComp) = try await TransitionUtility.configureMixComposition(
            videoAssets: assets,
            videoRanges: selectRanges,
            transitions: transitions,
            audioAssets: [],
            audioRanges: [],
            audioInsertTimes: [],
            transitionDuration: transitionDuration,
            videoSie: videoSize,
            frameDuration: frameRate) else {
            return nil
        }
        
        composition = mixComp
        videoComposition = videoComp
        return (mixComp, videoComp)
    }

    func swapAsset(_ asset1: VisualEditAsset, _ asset2: VisualEditAsset) -> Bool {
        let idx1 = visualAssets.firstIndex { a in
            return a.id == asset1.id
        }
        let idx2 = visualAssets.firstIndex { a in
            return a.id == asset2.id
        }
        
        guard let idx1, let idx2 else {
            return false
        }
        
        visualAssets.swapAt(idx1, idx2)
        // don't change the transitions
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
            transitions.append(.init(type: .None))
        }
        
        return check()
    }

    func addAudioAsset(_ asset: AudioEditAsset) -> Bool {
        audioAssets.append(asset)
        return true
    }
    
    private func check() -> Bool {
        if !visualAssets.isEmpty && visualAssets.count - 1 == transitions.count {
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
