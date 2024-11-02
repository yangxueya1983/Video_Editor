//
//  Clip.swift
//  TimeLineVC
//
//  Created by Yu Yang on 2024-10-27.
//

import AVFoundation

class Clip {
    let duration: CMTime
    var selectRange: CMTimeRange
    
    init(duration: CMTime, selectRange: CMTimeRange) {
        self.duration = duration
        self.selectRange = selectRange
    }
    
    func getLength(timeScale: Float, timeScaleLen: Float) -> CGFloat {
        let seconds = selectRange.duration.seconds
        return seconds / CGFloat(timeScale) * CGFloat(timeScaleLen)
    }
    
    func adjustTimeOffset(leftTimeOffset: inout CGFloat?, rightTimeOffset: inout CGFloat?)
    {
        if leftTimeOffset != nil {
            var start = selectRange.start.seconds + leftTimeOffset!
            start = max(0, start)
            start = min(start, selectRange.end.seconds - ClipConfig.minDuration)
            leftTimeOffset = start - selectRange.start.seconds
        }
        
        if rightTimeOffset != nil {
            var end = selectRange.end.seconds + rightTimeOffset!
            end = min(end, duration.seconds)
            end = max(end, selectRange.start.seconds + ClipConfig.minDuration)
            rightTimeOffset = end - selectRange.end.seconds
        }
    }
    
    func getLengthWithOffset(timeScale: Float, timeScaleLen: Float, leftOffsetTime: CGFloat?, rightOffsetTime: CGFloat?, isDragLeft: Bool?) -> CGFloat {
        
        if leftOffsetTime == nil && rightOffsetTime == nil {
            
        }
        
        let start = selectRange.start.seconds
        let end = selectRange.end.seconds
        
        var leftPos = start
        if let leftOffsetTime {
            leftPos = start + leftOffsetTime
        }
        
        // make sure >= 0
        leftPos = max(0, leftPos)
        leftPos = min(leftPos, duration.seconds - ClipConfig.minDuration)
        
        var rightPos = end
        if let rightOffsetTime {
            rightPos = end + rightOffsetTime
        }
        
        // make sure <= duration
        rightPos = min(rightPos, duration.seconds)
        rightPos = max(rightPos, ClipConfig.minDuration)
        
        guard let isDragLeft else {
            assert(false)
        }
        
        if isDragLeft {
            leftPos = min(leftPos, rightPos - ClipConfig.minDuration)
        } else {
            rightPos = max(rightPos, leftPos + ClipConfig.minDuration)
        }
        
        assert(leftPos < rightPos)
        
        return (rightPos - leftPos) / CGFloat(timeScale) * CGFloat(timeScaleLen)
    }
    
    func commitOffset(leftOffsetTime: CGFloat?, rightOffsetTime: CGFloat?, isDragLeft: Bool) {
        var start = selectRange.start.seconds
        var end = selectRange.end.seconds
        
        if let leftOffsetTime {
            start += leftOffsetTime
            start = max(0, start)
        }
        
        if let rightOffsetTime {
            end += rightOffsetTime
            end = min(end, duration.seconds)
        }
        
        if isDragLeft {
            start = min(start, end - ClipConfig.minDuration)
        } else {
            end = max(end, start + ClipConfig.minDuration)
        }
        
        let cmStart = CMTime(seconds: start, preferredTimescale: 10000)
        let cmEnd = CMTime(seconds: end, preferredTimescale: 10000)
        selectRange = CMTimeRange(start: cmStart, end: cmEnd)
    }
}

class AudioClip : Clip {
    var placeTime: CMTime
    
    init(duration: CMTime, selectRange: CMTimeRange, placeTime: CMTime) {
        self.placeTime = placeTime
        super.init(duration: duration, selectRange: selectRange)
    }
    
    func getPlaceX(timeScale: CGFloat, timeScaleLen: CGFloat)->CGFloat
    {
        return placeTime.seconds / timeScale * timeScaleLen
    }
    
    func noOverlapAdjust(clips: [AudioClip], leftTimeOffset: inout CGFloat?, rightTimeOffset: inout CGFloat?)
    {
        var left = placeTime.seconds
        var right = left + selectRange.duration.seconds
        
        if let leftTimeOffset {
            left += leftTimeOffset
        }
        
        if let rightTimeOffset {
            right += rightTimeOffset
        }
        
        for c in clips {
            if c === self {
                continue
            }
            
            let l = c.placeTime.seconds
            let r = l + c.selectRange.duration.seconds
            
            if l >= right || r <= left {
                // no overlap
                continue
            }
            
            if left < r {
                left = r
            }
            
            if right > l {
                right = l
            }
        }
        
        if leftTimeOffset != nil {
            leftTimeOffset = left - placeTime.seconds
        }
        
        if rightTimeOffset != nil {
            rightTimeOffset = right - (placeTime.seconds + selectRange.duration.seconds)
        }
    }
    
    func commitOffset(leftOffsetTime: CGFloat?, rightOffsetTime: CGFloat?, isDragLeft: Bool, sectionClips: [AudioClip]) {
        
        var left = leftOffsetTime
        var right = rightOffsetTime
        noOverlapAdjust(clips: sectionClips, leftTimeOffset: &left, rightTimeOffset: &right)
        
        let selRangeBefore = selectRange
        super.commitOffset(leftOffsetTime: left, rightOffsetTime: right, isDragLeft: isDragLeft)
        let selRangeAfter = selectRange
        
        // update the place time for left drag
        if isDragLeft {
            assert(left != nil)
            let offset = selRangeAfter.start.seconds - selRangeBefore.start.seconds
            let newPlaceTime = placeTime.seconds + offset
            placeTime = CMTime(seconds: newPlaceTime, preferredTimescale: 10000)
        }
    }
}
