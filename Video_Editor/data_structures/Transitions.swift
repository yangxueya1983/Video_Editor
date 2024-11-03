//
//  Transitions.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation
import AVFoundation

enum TransitionType : Int {
    case None
}

struct VideoTransition {
    let type: TransitionType
    let fromAssetIdx: Int
    let toAssetIdx: Int
}

struct TransitionUtility {
    static func configureMixComposition(videoAssets: [AVAsset], videoRanges:[CMTimeRange], audioAssets: [AVAsset], audioRanges:[CMTimeRange], audioInsertTimes: [CMTime], transitions: [VideoTransition], transitionDuration: CMTime) async throws -> (AVMutableComposition, AVMutableVideoComposition)? {
        
        if videoAssets.count != transitions.count - 1 || videoAssets.count != videoRanges.count || audioAssets.count != audioRanges.count {
            print("input error")
            return nil
        }
        
        let composition = AVMutableComposition()
        
        let videoTrack1 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let videoTrack2 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var audioTracks: [AVMutableCompositionTrack] = []
        
        guard let videoTrack1, let videoTrack2 else {
            print("composition create video track failed")
            return nil
        }
        
        for i in 0..<audioAssets.count {
            guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                print("composition create audio track failed")
                return nil
            }
            audioTracks.append(audioTrack)
        }
        
        // load video tracks simultaneously
        var loadVideoTracks = [AVAssetTrack?]()
        try await withThrowingTaskGroup(of: AVAssetTrack?.self, body: { group in
            for asset in videoAssets {
                group.addTask {
                    return try await asset.loadTracks(withMediaType: .video).first
                }
            }
            for try await result in group {
                loadVideoTracks.append(result)
            }
        })
        
        guard loadVideoTracks.allSatisfy({$0 != nil}) else {
            print("load video asset track failed")
            return nil
        }
        
        var loadAudioTracks: [AVAssetTrack?] = []
        try await withThrowingTaskGroup(of: AVAssetTrack?.self, body: { group in
            for asset in audioAssets {
                group.addTask {
                    return try await asset.loadTracks(withMediaType: .audio).first
                }
            }
            for try await result in group {
                loadAudioTracks.append(result)
            }
        })
        
        guard loadAudioTracks.allSatisfy({$0 != nil}) else {
            print("load audio asset track failed")
            return nil
        }
        
        let videoComposition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: composition)
        
        var instructionCfgs = [(CMTimeRange, [AVAssetTrack], TransitionType)]()
        // add video asset tracks
        var curInsertTime = CMTime.zero
        for (idx, videoTrack) in loadVideoTracks.enumerated() {
            let timeRange = videoRanges[idx]
            if idx % 2 == 0 {
                try videoTrack1.insertTimeRange(timeRange, of: videoTrack!, at: curInsertTime)
            } else {
                try videoTrack2.insertTimeRange(timeRange, of: videoTrack!, at: curInsertTime)
            }
            curInsertTime = CMTimeAdd(curInsertTime, timeRange.duration)
            curInsertTime = CMTimeSubtract(curInsertTime, transitionDuration)
        }
        
        // add layer instruction for video transitions
        for (idx, audioTrack) in loadAudioTracks.enumerated() {
            let timeRange = audioRanges[idx]
            let mutableTrack = audioTracks[idx]
            let insertTime = audioInsertTimes[idx]
            try mutableTrack.insertTimeRange(timeRange, of: audioTrack!, at: insertTime)
        }
        
        return (composition, videoComposition)
    }
    
    static func createTransitionInstruction(curTrack: AVAssetTrack, prevTrack: AVAssetTrack, timeRange: CMTimeRange, trans: TransitionType) -> [AVMutableVideoCompositionInstruction] {
        
        var ret: [AVMutableVideoCompositionInstruction] = []
        
        let i1 = AVMutableVideoCompositionInstruction()
        i1.timeRange = timeRange
        
        let l1 = AVMutableVideoCompositionLayerInstruction(assetTrack: curTrack)
        l1.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: 1, timeRange: timeRange)
        let l2 = AVMutableVideoCompositionLayerInstruction(assetTrack: prevTrack)
        l2.setOpacityRamp(fromStartOpacity: 1, toEndOpacity: 0, timeRange: timeRange)
        i1.layerInstructions = [l1, l2]
        ret.append(i1)
        return ret
    }
    
}
