//
//  Settings.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation
import AVFoundation

struct MediaSetting {
    static let photoMaxDuration: CGFloat = 5
}

struct EditorSetting {
    static let transitionTime: CMTime = CMTime(seconds: 0.5, preferredTimescale: 1000)
}
