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
    
    
    func testComposeVideos(transitionType: TransitionType, outputFileName: String) async throws {
        print("test type \(transitionType)")
        let tmpDirectory = NSTemporaryDirectory()
        let url1 = URL(fileURLWithPath: tmpDirectory + "test1.mp4")
        let url2 = URL(fileURLWithPath: tmpDirectory + "test2.mp4")
        let outURL = URL(filePath: tmpDirectory + outputFileName + ".mp4")
        
        for url in [url1, url2, outURL] {
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.removeItem(at: url)
            }
        }
        
        // create two videos
        let image1 = UIImage(named: "pic_1.jpg")!
        let image2 = UIImage(named: "pic_2.jpg")!
        let videoSize = CGSizeMake(1024, 768)
        let duration = CMTimeMake(value: 2, timescale: 1)
        let error1 = try await generateVideo(image: image1, size: videoSize, duration: duration, url: url1)
        let error2 = try await generateVideo(image: image2, size: videoSize, duration: duration, url: url2)
        #expect(error1 == nil && error2 == nil)
        
        // load the assets
        let asset1 = AVURLAsset(url: url1)
        let asset2 = AVURLAsset(url: url2)
        
        let range1 = CMTimeRangeMake(start: .zero, duration: duration)
        let range2 = CMTimeRangeMake(start: .zero, duration: duration)
        
        let transitionTypes: [TransitionType] = [transitionType]
        
        guard let (composition, videoComposition, duration) = try await TransitionUtility.configureMixComposition(videoAssets: [asset1, asset2], videoRanges: [range1, range2], transitions: transitionTypes, audioAssets: [], audioRanges: [], audioInsertTimes: [], transitionDuration: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), videoSie: videoSize, frameDuration: CMTime(value: 1, timescale: 60), customComposeClass: ExportCustomVideoCompositor.self) else {
            #expect(Bool(false))
            return
        }
        
        // export
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            #expect(Bool(false))
            return
        }
        
        print("will output to \(outURL.path)")
        exportSession.outputURL = outURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
        await exportSession.export()
        #expect(FileManager.default.fileExists(atPath: outURL.path))
        #expect(exportSession.status == .completed)
        
        // check the duration of the asset
        let asset = AVURLAsset(url: outURL)
        let d = try await asset.load(.duration)
        print("output duration: \(d.seconds)")
        #expect(d.seconds ==  3.5)
    }
    
    @Test("test none transition type")
    func testNoneTransitionType() async throws {
//        try await testComposeVideos(transitionType: .None, outputFileName: "none")
//        try await testComposeVideos(transitionType: .Dissolve, outputFileName: "disolve")
//        try await testComposeVideos(transitionType: .CircleEnlarge, outputFileName: "circle_enlarge")
//        try await testComposeVideos(transitionType: .MoveLeft, outputFileName: "move_left")
//        try await testComposeVideos(transitionType: .MoveRight, outputFileName: "move_right")
//        try await testComposeVideos(transitionType: .MoveUp, outputFileName: "move_up")
//        try await testComposeVideos(transitionType: .MoveDown, outputFileName: "move_down")
//        try await testComposeVideos(transitionType: .PageCurl, outputFileName: "page_curl")
        try await testComposeVideos(transitionType: .RadiusRotate, outputFileName: "radius_rotate")
    }
    
    @Test("test exportation")
    func testExportation() async throws {
        
        let projectDir = NSTemporaryDirectory() + "export_test"
        
        if FileManager.default.fileExists(atPath: projectDir) {
            _ = try? FileManager.default.removeItem(atPath: projectDir)
        }
        
        // get the configuration
        let config = ExportConfig()
        config.resolution = .R4K
        let project = EditProject(dir: projectDir)
        
        let asset1Dir = projectDir + "/asset1"
        let asset2Dir = projectDir + "/asset2"
        
        // load the image
        let image1 = UIImage(named: "pic_1.jpg")!
        let image2 = UIImage(named: "pic_2.jpg")!
        
        let asset1 = PhotoEditAsset(image: image1, cacheDir: asset1Dir)
        let asset2 = PhotoEditAsset(image: image2, cacheDir: asset2Dir)
        #expect(project.addVisualAsset(asset1) == true)
        #expect(project.addVisualAsset(asset2) == true)
        
        #expect(await asset1.process() == true)
        #expect(await asset2.process() == true)
        
        let outputPath = NSTemporaryDirectory() + "export_test.mp4"
        if FileManager.default.fileExists(atPath: outputPath) {
            _ = try? FileManager.default.removeItem(atPath: outputPath)
        }
        
        let outputURL = URL(fileURLWithPath: outputPath)
        print("export to path: \(outputPath)")
        
//        var ok = try await project.createCompositionAsset()
//        #expect(ok)
        var ok = try await project.export(to: outputURL, config: config)
        #expect(ok)
        
        PhotoMediaUtility.inspectVideoPropertiesForURL(videoURL: outputURL)
    }
}
