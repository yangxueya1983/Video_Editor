//
//  EditProject.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation

class CacheItem {
    init(rootDir: String) {
        // TODO: create individual directories
    }

    func check() -> Bool {
        return true
    }

    func addAsset(asset: EditAsset)-> Bool {
        return true
    }
}

class EditProject {
    private let projectID: UUID

    // include video asset photo asset
    private var visualAssets : [VisualEditAsset] = []
    // audio assets
    private var audioAssets: [AudioEditAsset] = []
    // transitions between visual assets
    private var transitions: [VideoTransition] = []

    private var id2AssetMap: [UUID: EditAsset] = [:]

    private var cacheItem: CacheItem

    init(cacheItem: CacheItem) {
        projectID = UUID()
        self.cacheItem = cacheItem
    }


    func swapAsset(_ asset1: VisualEditAsset, _ asset2: VisualEditAsset) -> Bool {
        return false
    }

    func rmAsset(_ asset: EditAsset) -> Bool {
        return false
    }
    
    func addVisualAsset(_ asset: VisualEditAsset) -> Bool {
        return false
    }

    func addAudioAsset(_ asset: AudioEditAsset) -> Bool {
        return false
    }
}

class CacheHelper {
    static func createNewCacheDirectory() -> CacheItem {
        return CacheItem(rootDir: "")
    }
}


class ArchiveManager {
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
