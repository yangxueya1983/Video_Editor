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
        
        let origPixelSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale)
        let drawRect = getScaleFitDrawRect(origPixelSize, videoSize)
        context?.draw(image.cgImage!, in: drawRect)
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
    
    static func scaleImage(_ image: UIImage, toMaxSize maxSize: CGFloat) -> UIImage? {
        let originalSize = image.size
        let widthRatio = maxSize / originalSize.width
        let heightRatio = maxSize / originalSize.height
        let scaleFactor = min(widthRatio, heightRatio)  // Scale down to fit within maxSize
        
        // Calculate the new size
        let newSize = CGSize(width: originalSize.width * scaleFactor, height: originalSize.height * scaleFactor)
        
        // Create a new image context and draw the resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)  // 0.0 uses the device's scale (e.g., Retina)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }

    static func getTimeLength(duration: Float, timeScale: Float, timeScaleLen: Float) -> Float {
        return duration / timeScale * timeScaleLen
    }
    
    static func inspectVideoPropertiesForURL(videoURL: URL) {
        let asset = AVURLAsset(url: videoURL)
        inspectVideoPropertiesForAsset(asset: asset)
    }
    
    static func inspectVideoPropertiesForAsset(asset: AVAsset) {
        // Get video track
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("No video track found")
            return
        }
        
        // **1. Video Size (Resolution)**
        let videoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        print("Video Size: \(abs(videoSize.width)) x \(abs(videoSize.height))")
        
        // **2. Frame Rate**
        let frameRate = videoTrack.nominalFrameRate
        print("Frame Rate: \(frameRate) fps")
        
        // **3. Bitrate**
        let bitrate = videoTrack.estimatedDataRate // Bits per second
        print("Bitrate: \(bitrate / 1000) kbps") // Convert to kbps
    }
    
    private static func getScaleFitDrawRect(_ natualSize: CGSize, _ renderSize: CGSize) -> CGRect {
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
        
        return CGRect(x : dx, y : dy, width : scaleWidth, height : scaleHeight)
    }
}
