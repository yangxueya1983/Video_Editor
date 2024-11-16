//
//  TimeLineDataModel.swift
//  TimeLineVC
//
//  Created by Yu Yang on 2024-10-02.
//

import Foundation
import AVFoundation

struct ClipConfig {
    static let minDuration: CGFloat = 1
}

struct TimeLineViewModel {
    var videoDuration: Float = 10
    
    let oneScaleMinLen: Float = 20
    let oneScaleMaxLen: Float = 40
    // each scale represent durations (in seconds), from high value to low value
    let scaleDurations: [Float] = [10, 5, 2.5, 1.5, 1, 0.5, 0.25, 1/6, 1/12, 1/20, 1/30]
    
    var minLen: Float {
        get {
            return (videoDuration / scaleDurations.first!) * oneScaleMinLen
        }
    }
    
    var maxLen: Float {
        get {
            return (videoDuration / scaleDurations.last!) * oneScaleMaxLen
        }
    }
    
    func getMaxMinLengthForTimeScale(scale: Float) -> (Float, Float) {
        let minLength = (videoDuration / scale) * oneScaleMinLen
        let maxLength = (videoDuration / scale) * oneScaleMaxLen
        
        return (minLength, maxLength)
    }
    
    func getSingleScaleLengthForTimeScale(len: Float) -> Float {
        let timeScale = getScaleForLength(len: len)
        return len / videoDuration * timeScale
    }
    
    func getScaleForLength(len: Float) -> Float {
        for scale in scaleDurations {
            let (minLen, maxLen) = getMaxMinLengthForTimeScale(scale: scale)
            if minLen <= len && len <= maxLen {
                return scale
            }
        }
        
        assert(false, "can't get valid scale")
        
        return -1
    }
    
    // clips utility
    
}

