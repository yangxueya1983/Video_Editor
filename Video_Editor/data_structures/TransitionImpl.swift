//
//  TransitionImpl.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-03.
//


import AVFoundation
import Foundation
import CoreImage


class NoneTransCompsitionInstruction: CustomVideoCompositionInstructionBase {
    override func compose(_ frontSample: CIImage, _ backgroundSample: CIImage, _ process: CGFloat, _ size: CGSize) -> CIImage? {
        return frontSample
    }
}

class CrossDissolveCompositionInstruction : CustomVideoCompositionInstructionBase {
    override func compose(_ frontSample: CIImage, _ backgroundSample: CIImage, _ process: CGFloat, _ size: CGSize) -> CIImage? {
        let blendedImage = frontSample.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: backgroundSample,
            kCIInputMaskImageKey: CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: process)).cropped(to: frontSample.extent)
        ])
        
        return blendedImage
    }
}
