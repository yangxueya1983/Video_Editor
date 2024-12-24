//
//  Transitions.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation
import AVFoundation

enum TransitionType : Int, Codable {
    case None
    case Dissolve
    case CircleEnlarge
    case MoveLeft
    case MoveRight
    case MoveUp
    case MoveDown
    case PageCurl
    case RadiusRotate
}

// factory design patterhn
class TransitionFactory {
    static func createCompositionInstruction(type: TransitionType) -> AVMutableVideoCompositionInstruction? {
        switch type {
        case .None:
            return NoneTransCompsitionInstruction()
        case .Dissolve:
            return CrossDissolveCompositionInstruction()
        case .CircleEnlarge:
            return CircleEnlargerCompositionInstruction()
        case .MoveLeft:
            return MoveLeftInstruction()
        case .MoveRight:
            return MoveRightInstruction()
        case .MoveUp:
            return MoveUpInstruction()
        case .MoveDown:
            return MoveDownInstruction()
        case .PageCurl:
            return PageCurlInstruction()
        case .RadiusRotate:
            return RadiusRotateInstruction()
        default :
            return nil
        }
    }
}

struct VideoTransition : Codable {
    let type: TransitionType
//    let fromAssetIdx: Int
//    let toAssetIdx: Int
    
    enum CodingKeys: String, CodingKey {
        case transitionType
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .transitionType)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(TransitionType.self, forKey: .transitionType)
    }
    
    init(type: TransitionType) {
        self.type = type
    }
}

struct TransitionUtility {
    
    /// create the video composition
    /// - Parameters:
    ///   - videoAssets: video assets
    ///   - videoRanges: time ranges for each video asset
    ///   - transitions: transition types
    ///   - audioAssets: audio assets
    ///   - audioRanges: audio select ranges
    ///   - audioInsertTimes: insert time for each audio asset
    ///   - transitionDuration: video transition duration, each video duration must be greater than this value
    ///   - videoSie: genreated video size
    ///   - frameDuration: frame rates to generate
    /// - Returns: (composition, video composition, duration)
    static func configureMixComposition(videoAssets: [AVAsset], videoRanges:[CMTimeRange], transitions: [TransitionType],audioAssets: [AVAsset], audioRanges:[CMTimeRange], audioInsertTimes: [CMTime], transitionDuration: CMTime, videoSie: CGSize, frameDuration: CMTime, customComposeClass: (any AVVideoCompositing.Type)) async throws -> (AVMutableComposition, AVMutableVideoComposition, CMTime)? {
        
        if videoAssets.count != transitions.count + 1 || videoAssets.count != videoRanges.count || audioAssets.count != audioRanges.count {
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
        
        for _ in 0..<audioAssets.count {
            guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                print("composition create audio track failed")
                return nil
            }
            audioTracks.append(audioTrack)
        }
        
        // load video tracks simultaneously
        var loadVideoTracks : [AVAssetTrack?] = Array(repeating: nil, count: videoAssets.count)
        try await withThrowingTaskGroup(of: (Int, AVAssetTrack?).self, body: { group in
            for (index,asset) in videoAssets.enumerated() {
                group.addTask {
                    let asset = try await asset.loadTracks(withMediaType: .video).first
                    return (index, asset)
                }
            }
            for try await (idx, result) in group {
                loadVideoTracks[idx] = result
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
        videoComposition.customVideoCompositorClass = customComposeClass
        
        var instructionCfgs = [(CMTimeRange, [AVAssetTrack], [CGAffineTransform], TransitionType)]()
        
        var transforms : [CGAffineTransform] = []
        for (idx, videoTrack) in loadVideoTracks.enumerated() {
            let natualSize = try await videoTrack!.load(.naturalSize)
            let transform = getTransform(natualSize: natualSize, renderSize: videoSie)
            transforms.append(transform)
        }
        
        // add video asset tracks
        var curInsertTime = CMTime.zero
        for (idx, videoTrack) in loadVideoTracks.enumerated() {
            let natualSize = try await videoTrack!.load(.naturalSize)
            let timeRange = videoRanges[idx]
            if idx % 2 == 0 {
                try videoTrack1.insertTimeRange(timeRange, of: videoTrack!, at: curInsertTime)
            } else {
                try videoTrack2.insertTimeRange(timeRange, of: videoTrack!, at: curInsertTime)
            }
            
            // all time ranges should be considered
            let hasPreviousTrack = idx > 0
            let hasNextTrack = idx < loadVideoTracks.count - 1
            var transitionType: TransitionType = .None
            if idx > 0 {
                transitionType = transitions[idx-1]
            }
            
            var singleTrackStartTime = curInsertTime
            var singleTrackDuration = timeRange.duration
            if hasPreviousTrack {
                singleTrackStartTime = CMTimeAdd(curInsertTime, transitionDuration)
                // subtract previous transition time
                singleTrackDuration = CMTimeSubtract(timeRange.duration, transitionDuration)
            }
            if hasNextTrack {
                // subtract the next transition time
                singleTrackDuration = CMTimeSubtract(singleTrackDuration, transitionDuration)
            }

            if hasPreviousTrack {
                // add transition instruction
                let transitionTimeRange = CMTimeRange(start: curInsertTime, duration: transitionDuration)
                // front sample, background sample
                let instructionTracks = idx % 2 == 0 ? [videoTrack1, videoTrack2] : [videoTrack2, videoTrack1]
                // front track (will show), background track(will fade)
                let ts = [transforms[idx], transforms[idx-1]]
                instructionCfgs.append((transitionTimeRange, instructionTracks, ts, transitionType))
            }
            
            // add single track instruction
            instructionCfgs.append((CMTimeRange(start: singleTrackStartTime, duration: singleTrackDuration), [idx % 2 == 0 ? videoTrack1 : videoTrack2], [transforms[idx]],.None))
            
            curInsertTime = CMTimeAdd(curInsertTime, timeRange.duration)
            if idx < loadVideoTracks.count - 1 {
                // for not last element, subtract transition duration
                curInsertTime = CMTimeSubtract(curInsertTime, transitionDuration)
            }
        }
        
        // curInsertTime is the total duration
        let totalDuration = curInsertTime
        
        videoComposition.instructions = generateInstructions(configures: instructionCfgs, totalTime: curInsertTime)
        videoComposition.renderSize = videoSie
        videoComposition.frameDuration = frameDuration
        
        // add layer instruction for video transitions
        for (idx, audioTrack) in loadAudioTracks.enumerated() {
            let timeRange = audioRanges[idx]
            let mutableTrack = audioTracks[idx]
            let insertTime = audioInsertTimes[idx]
            try mutableTrack.insertTimeRange(timeRange, of: audioTrack!, at: insertTime)
        }
        
        return (composition, videoComposition, totalDuration)
    }
    
    private static func getTransform(natualSize: CGSize, renderSize: CGSize) -> CGAffineTransform {
        let targetAR = renderSize.width / renderSize.height
        let sourceAR = natualSize.width / natualSize.height
        
        var scale: CGFloat = 0
        
        if sourceAR > targetAR {
            scale = renderSize.width / natualSize.width
        } else {
            scale = renderSize.height / natualSize.height
        }
        
        let scaleWidth = scale * natualSize.width
        let scaleHeight = scale * natualSize.height
        
        let dx = (renderSize.width - scaleWidth) / 2.0
        let dy = (renderSize.height - scaleHeight) / 2.0
        
        return CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
    }
    
    private static func generateInstructions(configures: [(CMTimeRange, [AVAssetTrack], [CGAffineTransform], TransitionType)], totalTime: CMTime) -> [AVMutableVideoCompositionInstruction] {
        var ret:[AVMutableVideoCompositionInstruction] = []
        
        // check time range correct or not
        var check: Bool = true
        var curTime: CMTime = .zero
        for (timeRange, tracks, ts, trans) in configures {
            if curTime != timeRange.start || tracks.count != ts.count {
                check = false
                break
            }
            
            curTime = CMTimeAdd(curTime, timeRange.duration)
        }
        
        guard check else {
            print("layer instruction check failed")
            return ret
        }
        
        // add layer instrction
        for (timeRange, tracks, ts, trans) in configures {
            if tracks.count == 1 {
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRange
                // layer instruction
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: tracks[0])
                layerInstruction.setTransform(ts[0], at: .zero)
//                layerInstruction.setTransformRamp(fromStart: ts[0], toEnd: ts[0], timeRange: timeRange)
                instruction.layerInstructions = [layerInstruction]
                ret.append(instruction)
                continue
            }
            
            assert(tracks.count == 2)
            guard let instruction = TransitionFactory.createCompositionInstruction(type: trans) else {
                assert(false)
            }
            instruction.timeRange = timeRange
            let layerInstruction1 = AVMutableVideoCompositionLayerInstruction(assetTrack: tracks[0])
            let layerInstruction2 = AVMutableVideoCompositionLayerInstruction(assetTrack: tracks[1])
            // hacking the code to force to use custom transition
            layerInstruction1.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: 1, timeRange: timeRange)
            layerInstruction2.setOpacityRamp(fromStartOpacity: 1, toEndOpacity: 0, timeRange: timeRange)
            layerInstruction1.setTransform(ts[0], at: .zero)
            layerInstruction2.setTransform(ts[1], at: .zero)
            instruction.layerInstructions = [layerInstruction1, layerInstruction2]
            ret.append(instruction)
        }
        
        return ret
    }
    
}
