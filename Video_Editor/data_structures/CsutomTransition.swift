//
//  CsutomTransition.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation
import AVFoundation
import CoreVideo
import CoreImage
import UIKit
import CoreImage.CIFilterBuiltins

class CustomVideoCompositionInstructionBase : AVMutableVideoCompositionInstruction {
    func compose(_ frontSample: CIImage, _ backgroundSample: CIImage, _ progress : CGFloat, _ size: CGSize) -> CIImage? {
        return nil
    }
}

// set the instruction base
class InstructionStore {
    static var shared: InstructionStore = .init()
    var instructions: [AVMutableVideoCompositionInstruction] = []
}

class CustomVideoCompositor: NSObject, AVVideoCompositing {
    private let renderContextQueue = DispatchQueue(label: "com.example.CustomVideoCompositor.renderContextQueue")
    private let renderingQueue = DispatchQueue(label: "com.example.CustomVideoCompositor.renderingQueue")
    private var renderContext: AVVideoCompositionRenderContext?
    private var timeRange2Instruction: [CMTimeRange : AVMutableVideoCompositionInstruction] = [:]
    
    // Specify the required pixel buffer attributes
    var sourcePixelBufferAttributes: [String : Any]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
    }
    
    // Render context is updated when the composition starts
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderContextQueue.sync {
            renderContext = newRenderContext
        }
    }
    
    // Main rendering method
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        if timeRange2Instruction.isEmpty {
            // populate it
            let instrs = InstructionStore.shared.instructions
            assert(instrs.count > 0)
            for inst in instrs {
                let range = inst.timeRange
                timeRange2Instruction[range] = inst
            }
        }
        
        renderingQueue.async {
            guard let renderContext = self.renderContext else {
                asyncVideoCompositionRequest.finish(with: NSError(domain: "CustomVideoCompositor", code: 0, userInfo: nil))
                return
            }
            
            let videoSize = renderContext.size
            
            if asyncVideoCompositionRequest.sourceTrackIDs.count == 1 {
                // pass through for only 1 track
                guard let frame = asyncVideoCompositionRequest.sourceFrame(byTrackID: asyncVideoCompositionRequest.sourceTrackIDs[0].int32Value) else {
                    print("compositor single track frame is nil")
                    return
                }
                
                asyncVideoCompositionRequest.finish(withComposedVideoFrame: frame)
                return
            }
            
            // Retrieve source frames
            guard let foregroundFrame = asyncVideoCompositionRequest.sourceFrame(byTrackID: asyncVideoCompositionRequest.sourceTrackIDs[0].int32Value),
                  let backgroundFrame = asyncVideoCompositionRequest.sourceFrame(byTrackID: asyncVideoCompositionRequest.sourceTrackIDs[1].int32Value) else {
                asyncVideoCompositionRequest.finish(with: NSError(domain: "CustomVideoCompositor", code: 1, userInfo: nil))
                return
            }
            
            // Apply transition effect (crossfade example)
            let instrTimeRange = asyncVideoCompositionRequest.videoCompositionInstruction.timeRange
            assert(CMTimeCompare(instrTimeRange.start, asyncVideoCompositionRequest.compositionTime) <= 0)
            let transitionFactor =  CGFloat(CMTimeGetSeconds(CMTimeSubtract(asyncVideoCompositionRequest.compositionTime, instrTimeRange.start)))  / CMTimeGetSeconds(asyncVideoCompositionRequest.videoCompositionInstruction.timeRange.duration)
            let outputPixelBuffer = renderContext.newPixelBuffer()
            
            // Create CIImages from the pixel buffers
            let ciForeground = CIImage(cvPixelBuffer: foregroundFrame)
            let ciBackground = CIImage(cvPixelBuffer: backgroundFrame)
            
            guard let origInstruction = self.timeRange2Instruction[instrTimeRange], let instruction = origInstruction as? CustomVideoCompositionInstructionBase else {
                asyncVideoCompositionRequest.finish(with: NSError(domain: "instruction is not CustomVideoCompositionInstructionBase", code: 0))
                return
            }
            
//            guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? CustomVideoCompositionInstructionBase else {
//                asyncVideoCompositionRequest.finish(with: NSError(domain: "instruction is not CustomVideoCompositionInstructionBase", code: 0))
//                return
//            }
            
            let blendedImage = instruction.compose(ciForeground, ciBackground, transitionFactor, videoSize)
            
            // Render the blended image into the output buffer
            let ciContext = CIContext()
            ciContext.render(blendedImage!, to: outputPixelBuffer!)
            
            // Finish the request with the output pixel buffer
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: outputPixelBuffer!)
        }
    }
    
    func cancelAllPendingVideoCompositionRequests() {
        renderingQueue.sync {
            // Cancel any pending requests
        }
    }
}



