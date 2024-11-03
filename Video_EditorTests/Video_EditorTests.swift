//
//  Video_EditorTests.swift
//  Video_EditorTests
//
//  Created by Yu Yang on 2024-11-01.
//

import Testing
import UIKit
import AVFoundation
@testable import Video_Editor

struct Video_EditorTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test("single photo to video")
    func testPhoto2Video() async throws {
        if let image1 = UIImage(named: "pic_1.jpg") {
            let videoSize = CGSizeMake(1024, 768)
            // why it has 10 seconds?
            let duration = CMTimeMake(value: 5, timescale: 1)
            let tempDir = NSTemporaryDirectory()
            let outputURL = URL(fileURLWithPath: tempDir + "test.mp4")
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                _ = try FileManager.default.removeItem(at: outputURL)
            }
            print(outputURL)
            
            let error = try await PhotoMediaUtility.createVideoFromImage(image: image1, videoSize: videoSize, duration: duration, outputURL: outputURL)
            
            #expect(error == nil)
        }
    }
    
    func generateVideo(image: UIImage, size: CGSize, duration: CMTime, url: URL) async throws -> Error? {
        try await PhotoMediaUtility.createVideoFromImage(image: image, videoSize: size, duration: duration, outputURL:url)
    }
    
    @Test("parallel photos to videos")
    func testMultiplePhoto2Video() async throws {
        var outputUrls: [URL] = []
        
        let tmpDirectory = NSTemporaryDirectory()
        
        for i in 0..<10 {
            let url = URL(fileURLWithPath: tmpDirectory + "test_\(i).mp4")
            outputUrls.append(url)
            
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.removeItem(at: url)
            }
        }
        
        var results: [(any Error)?] = []
        
        try await withThrowingTaskGroup(of: Error?.self) { group in
            let image1 = UIImage(named: "pic_1.jpg")!
            let videoSize = CGSizeMake(1024, 768)
            let duration = CMTimeMake(value: 5, timescale: 1)
            for url in outputUrls {
                group.addTask {
                    return try await generateVideo(image: image1, size: videoSize, duration: duration, url: url)
                }
            }
            
            for try await result in group {
                results.append(result)
            }
        }
        
        #expect(results.allSatisfy{$0 == nil})
    }

}
