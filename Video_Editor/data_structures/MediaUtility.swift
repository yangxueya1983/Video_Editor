//
//  MediaUtility.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation
import AVFoundation
import UIKit

// photo to video utlity
struct PhotoMediaUtility {
    static func createVideoFromImage(image: UIImage, videoSize: CGSize, duration: CMTime, outputURL: URL) async throws -> Error?  {
        // Set up the video writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let settings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height
        ] as [String: Any]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
        
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Create a pixel buffer pool
        let bufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: videoSize.width,
            kCVPixelBufferHeightKey as String: videoSize.height
        ]
        var pixelBufferPool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, bufferAttributes as CFDictionary, &pixelBufferPool)
        
        // Convert images to video
        guard let pixelBufferPool = pixelBufferPool else {
            return NSError(domain: "PhotoMeidaUtility", code: 1, userInfo: nil)
        }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
        
        guard let buffer = pixelBuffer else {
            return NSError(domain: "PhotoMeidaUtility", code: 2, userInfo: nil)
        }
        
        // Draw image on the pixel buffer
        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(videoSize.width), height: Int(videoSize.height),
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        while !writerInput.isReadyForMoreMediaData {}
        
        adaptor.append(buffer, withPresentationTime: .zero)
        // use duration / 2 so the total time is duration
        let halfDuration = CMTime(seconds: duration.seconds / 2, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        adaptor.append(buffer, withPresentationTime: halfDuration)
        
        writerInput.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            return writer.error
        }
        
        return nil
    }
}
