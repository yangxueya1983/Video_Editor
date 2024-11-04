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

class CircleEnlargerCompositionInstruction : CustomVideoCompositionInstructionBase {
    func createCenterRadiusMask(size: CGSize, progress: CGFloat) -> CIImage? {
        let center = CIVector(x: size.width / 2, y: size.height / 2)
        let radius = sqrt(size.width * size.width +  size.height * size.height) / 2  * progress
        
        // Create a radial gradient filter for the transition effect
        let gradientFilter = CIFilter(name: "CIRadialGradient")!
        gradientFilter.setValue(center, forKey: "inputCenter")
        gradientFilter.setValue(radius, forKey: "inputRadius0") // Inner radius (start of gradient)
        gradientFilter.setValue(radius + 1, forKey: "inputRadius1") // Outer radius (end of gradient)
        gradientFilter.setValue(CIColor.white, forKey: "inputColor0") // Inside color (visible area)
        gradientFilter.setValue(CIColor.black, forKey: "inputColor1") // Outside color (masked area)
        
        // Crop the gradient to the image size
        return gradientFilter.outputImage?.cropped(to: CGRect(origin: .zero, size: size))
    }
    
    override func compose(_ frontSample: CIImage, _ backgroundSample: CIImage, _ process: CGFloat, _ size: CGSize) -> CIImage? {
        let maskImage = self.createCenterRadiusMask(size: size, progress: process)
        let blendFilter = CIFilter(name: "CIBlendWithMask")
        blendFilter?.setValue(frontSample, forKey: kCIInputImageKey)
        blendFilter?.setValue(backgroundSample, forKey: kCIInputBackgroundImageKey)
        blendFilter?.setValue(maskImage, forKey: kCIInputMaskImageKey)
        
        return blendFilter?.outputImage
    }
}


class MoveLeftInstruction : CustomVideoCompositionInstructionBase {
    override func compose(_ frontSample: CIImage, _ backgroundSample: CIImage, _ process: CGFloat, _ size: CGSize) -> CIImage? {
        let offset = -size.width * process
        let transform = CGAffineTransformMakeTranslation(offset, 0)
        let transformImage = backgroundSample.applyingFilter("CIAffineTransform", parameters: [kCIInputTransformKey : transform])
        let outImage = transformImage.applyingFilter("CISourceAtopCompositing", parameters: [
            kCIInputBackgroundImageKey : frontSample
        ])
        
        return outImage
    }
}

class MoveRightInstruction : CustomVideoCompositionInstructionBase {
    override func compose(_ frontSample: CIImage, _ backgroundSample: CIImage, _ process: CGFloat, _ size: CGSize) -> CIImage? {
        let offset = size.width * process
        let transform = CGAffineTransformMakeTranslation(offset, 0)
        let transformImage = backgroundSample.applyingFilter("CIAffineTransform", parameters: [kCIInputTransformKey : transform])
        let outImage = transformImage.applyingFilter("CISourceAtopCompositing", parameters: [
            kCIInputBackgroundImageKey : frontSample
        ])
        
        return outImage
    }
}

class MoveUpInstruction: CustomVideoCompositionInstructionBase {
    override func compose(_ frontSample: CIImage, _ backgroundSample: CIImage, _ process: CGFloat, _ size: CGSize) -> CIImage? {
        let offset = size.height * process
        let transform = CGAffineTransformMakeTranslation(0, offset)
        let transformImage = backgroundSample.applyingFilter("CIAffineTransform", parameters: [kCIInputTransformKey : transform])
        let outImage = transformImage.applyingFilter("CISourceAtopCompositing", parameters: [
            kCIInputBackgroundImageKey : frontSample
        ])
        
        return outImage
    }
}

class MoveDownInstruction: CustomVideoCompositionInstructionBase {
    override func compose(_ frontSample: CIImage, _ backgroundSample: CIImage, _ process: CGFloat, _ size: CGSize) -> CIImage? {
        let offset = -size.height * process
        let transform = CGAffineTransformMakeTranslation(0, offset)
        let transformImage = backgroundSample.applyingFilter("CIAffineTransform", parameters: [kCIInputTransformKey : transform])
        let outImage = transformImage.applyingFilter("CISourceAtopCompositing", parameters: [
            kCIInputBackgroundImageKey : frontSample
        ])
        
        return outImage
    }
}

class PageCurlInstruction : CustomVideoCompositionInstructionBase {
    override func compose(_ frontSample: CIImage, _ backgroundSample: CIImage, _ progress: CGFloat, _ size: CGSize) -> CIImage? {
        let transitionFilter = CIFilter.pageCurlTransition()
        transitionFilter.inputImage = backgroundSample
        transitionFilter.targetImage = frontSample
        transitionFilter.time = Float(progress) // Adjust the time from 0 to 1 to control the transition progress
        transitionFilter.angle = Float(Double.pi) // Control the angle of the curl
        transitionFilter.radius = 100.0 // Control the radius of the curl
        transitionFilter.extent = frontSample.extent // Set the extent of the transition
        return transitionFilter.outputImage
    }
}
