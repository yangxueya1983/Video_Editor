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
    
    func getLayerInstruction(request: AVAsynchronousVideoCompositionRequest) -> CustomVideoCompositionInstructionBase? {
        assert(false, "getLayerInstruction is not implemented")
        return nil
    }
    
    // Main rendering method
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        renderingQueue.async {
            guard let renderContext = self.renderContext else {
                request.finish(with: NSError(domain: "CustomVideoCompositor", code: 0, userInfo: nil))
                return
            }
            
            let videoSize = renderContext.size
            
            if request.sourceTrackIDs.count == 1 {
                // pass through for only 1 track
                guard let frame = request.sourceFrame(byTrackID: request.sourceTrackIDs[0].int32Value) else {
                    print("compositor single track frame is nil")
                    return
                }
                
                var startTransform: CGAffineTransform = .identity
                var endTransform: CGAffineTransform = .identity
                var timeRange: CMTimeRange = .invalid
                
                if let instruction = request.videoCompositionInstruction as? AVMutableVideoCompositionInstruction {
                    instruction.layerInstructions.forEach { layerInstruction in
                        layerInstruction.getTransformRamp(for: .zero, start: &startTransform, end: &endTransform, timeRange: &timeRange)
                    }
                }
                
                let ciImage = CIImage(cvPixelBuffer: frame)
                let transformImage = ciImage.transformed(by: startTransform)
                let ciContext = CIContext()
                guard let outputPixelBuffer = renderContext.newPixelBuffer() else {
                    request.finish(with: NSError(domain: "CustomVideoCompositor", code: -2, userInfo: nil))
                    return
                }
                ciContext.render(transformImage, to: outputPixelBuffer)

                request.finish(withComposedVideoFrame: outputPixelBuffer)
                return
            }
            
            // Retrieve source frames
            guard let foregroundFrame = request.sourceFrame(byTrackID: request.sourceTrackIDs[0].int32Value),
                  let backgroundFrame = request.sourceFrame(byTrackID: request.sourceTrackIDs[1].int32Value) else {
                request.finish(with: NSError(domain: "CustomVideoCompositor", code: 1, userInfo: nil))
                return
            }
            
            // Apply transition effect (crossfade example)
            let instrTimeRange = request.videoCompositionInstruction.timeRange
            assert(CMTimeCompare(instrTimeRange.start, request.compositionTime) <= 0)
            let transitionFactor =  CGFloat(CMTimeGetSeconds(CMTimeSubtract(request.compositionTime, instrTimeRange.start)))  / CMTimeGetSeconds(request.videoCompositionInstruction.timeRange.duration)
            let outputPixelBuffer = renderContext.newPixelBuffer()
            
            // Create CIImages from the pixel buffers
            let ciForeground = CIImage(cvPixelBuffer: foregroundFrame)
            let ciBackground = CIImage(cvPixelBuffer: backgroundFrame)
            
            let beginEndTransforms = self.getLayerTransforms(request)
            assert(beginEndTransforms.count == 2)
            let ciForegroundTransform = ciForeground.transformed(by: beginEndTransforms[0].0)
            let ciBackgroundTransform = ciBackground.transformed(by: beginEndTransforms[1].0)
            
            
//            guard let origInstruction = self.timeRange2Instruction[instrTimeRange], let instruction = origInstruction as? CustomVideoCompositionInstructionBase else {
//                asyncVideoCompositionRequest.finish(with: NSError(domain: "instruction is not CustomVideoCompositionInstructionBase", code: 0))
//                return
//            }
            
            guard let instruction = self.getLayerInstruction(request: request) else {
                request.finish(with: NSError(domain: "instruction is not CustomVideoCompositionInstructionBase", code: 0))
                return
            }
            
//            guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? CustomVideoCompositionInstructionBase else {
//                asyncVideoCompositionRequest.finish(with: NSError(domain: "instruction is not CustomVideoCompositionInstructionBase", code: 0))
//                return
//            }
            
            
            let blendedImage = instruction.compose(ciForegroundTransform, ciBackgroundTransform, transitionFactor, videoSize)
            
            // Render the blended image into the output buffer
            let ciContext = CIContext()
            ciContext.render(blendedImage!, to: outputPixelBuffer!)
            
            // Finish the request with the output pixel buffer
            request.finish(withComposedVideoFrame: outputPixelBuffer!)
        }
    }
    
    func cancelAllPendingVideoCompositionRequests() {
        renderingQueue.sync {
            // Cancel any pending requests
        }
    }
    
    func getLayerTransforms(_ request: AVAsynchronousVideoCompositionRequest) -> [(CGAffineTransform, CGAffineTransform)] {
        var ret = [(CGAffineTransform, CGAffineTransform)]()
        
        if let instruction = request.videoCompositionInstruction as? AVMutableVideoCompositionInstruction {
            instruction.layerInstructions.forEach { layerInstruction in
                var startTransform: CGAffineTransform = .identity
                var endTransform: CGAffineTransform = .identity
                var timeRange: CMTimeRange = .invalid
                if layerInstruction.getTransformRamp(for: .zero, start: &startTransform, end: &endTransform, timeRange: &timeRange) {
                    ret.append((startTransform, endTransform))
                }
            }
        }
        
        return ret
    }
}


class ExportCustomVideoCompositor :  CustomVideoCompositor {
    override func getLayerInstruction(request: AVAsynchronousVideoCompositionRequest) -> CustomVideoCompositionInstructionBase? {
        if let instruction = request.videoCompositionInstruction as? CustomVideoCompositionInstructionBase {
            return instruction
        }
        return nil
    }
}


class PlaybackCustomVideoCompositor : CustomVideoCompositor {
    private var timeRange2Instruction: [CMTimeRange : AVMutableVideoCompositionInstruction] = [:]
    override func getLayerInstruction(request: AVAsynchronousVideoCompositionRequest) -> CustomVideoCompositionInstructionBase? {
        if timeRange2Instruction.isEmpty {
            // populate it
            let instrs = InstructionStore.shared.instructions
            assert(instrs.count > 0)
            for inst in instrs {
                let range = inst.timeRange
                timeRange2Instruction[range] = inst
            }
        }
        let instrTimeRange = request.videoCompositionInstruction.timeRange
        guard let origInstruction = self.timeRange2Instruction[instrTimeRange], let instruction = origInstruction as? CustomVideoCompositionInstructionBase else {
            return nil
        }
        
        return instruction
    }
}


