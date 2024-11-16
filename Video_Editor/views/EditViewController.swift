//
//  EditView.swift
//  TimeLineVC
//
//  Created by Yu Yang on 2024-10-19.
//

import SwiftUI
import AVFoundation
import SnapKit


public struct EditViewWrapper: View {
    @State var videoURL: URL?
    
    public var body: some View {
        EditView()
    }
}

struct EditView: UIViewControllerRepresentable {
    typealias UIViewControllerType = EditViewController
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        let ret = EditViewController()
        
        return ret
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
}

struct EditViewConfig {
    static let headerHeight: CGFloat = 40
}

class EditViewController: UIViewController, TimeLineControllerProtocol {
    var headerView: UIView!
    var bottomView: UIView!
    var videoConfigBtn: UIButton!
    var playPauseBtn: UIButton!
    var dismissBtn: UIButton!
    var playerView: UIView!
    var videoConfigureView: UIView!
    var player: AVPlayer!
    var playerLayer: AVPlayerLayer!
    var timeLineVC: TimeLineViewController!
    
    // data model
    var project: EditProject!
    
    var timeObserverToken: Any?
    
    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTopHeaderView()
        configureBottomView()
        configurePlayerView()
        configureVideoConfigureView()
        
        self.view.backgroundColor = .init(hex: "#141414")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    private func configureTopHeaderView() {
        headerView = UIView()
        headerView.backgroundColor = .init(hex: "#141414")
        self.view.addSubview(headerView)
        headerView.layer.zPosition = 1
        
        headerView.snp.makeConstraints { make in
            make.left.right.equalTo(self.view)
            make.height.equalTo(EditViewConfig.headerHeight)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
        }
        
        // dismiss button
        dismissBtn = UIButton()
        dismissBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        dismissBtn.addTarget(self, action: #selector (dismissBtnPressed), for: .touchUpInside)
        
        headerView.addSubview(dismissBtn)
        dismissBtn.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.height.equalTo(19)
//            make.width.equalTo(19)
        }
        
        // add EXPORT button
        let exportBtn = UIButton(type: .custom)
        exportBtn.addTarget(self, action: #selector (exportButtonPressed), for: .touchUpInside)
        exportBtn.backgroundColor = .init(hex: "00CEE2")
        exportBtn.layer.cornerRadius = 5
        
        var exportConfig = UIButton.Configuration.plain()
        exportConfig.title = "Export"
        exportConfig.attributedTitle = AttributedString("Export", attributes: AttributeContainer([.font: UIFont.boldSystemFont(ofSize: 16)]))
        exportConfig.baseForegroundColor = .black
        exportBtn.configuration = exportConfig
        exportBtn.configuration?.baseForegroundColor = .black
        
        headerView.addSubview(exportBtn)
        exportBtn.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
            make.height.equalTo(33)
        }
  
        
        // add video configure button
        videoConfigBtn = UIButton(type: .custom)
        videoConfigBtn.backgroundColor = .init(hex: "29292B")
        
        configureVideoConfigureButton(btn: videoConfigBtn, show: true)
        
        headerView.addSubview(videoConfigBtn)
        videoConfigBtn.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(exportBtn.snp.left).offset(-10)
        }
        
        videoConfigBtn.addTarget(self, action: #selector (videoCfgButtonPressed), for: .touchUpInside)
    }

    private func configureBottomView() {
        bottomView = UIView()
        bottomView.backgroundColor = .red
        
        self.view.addSubview(bottomView)
        
        bottomView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(287)
        }
        
        let bottomHeader = UIView()
        bottomHeader.backgroundColor = .clear
        bottomView.addSubview(bottomHeader)
        bottomHeader.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(40)
        }
        
        // full screen button
        let scaleButton = UIButton(type:.custom)
        scaleButton.setImage(UIImage(systemName: "arrow.down.left.and.arrow.up.right"), for: .normal)
        bottomHeader.addSubview(scaleButton)
        scaleButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(20)
            make.width.equalTo(scaleButton.snp.height)
        }
        scaleButton.addTarget(self, action: #selector(scaleUpButtonPressed), for: .touchUpInside)
        
        // play button in the center
        playPauseBtn = UIButton(type:.custom)
        playPauseBtn.setImage(UIImage(systemName: "play"), for: .normal)
        bottomHeader.addSubview(playPauseBtn)
        playPauseBtn.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.width.equalTo(playPauseBtn.snp.height)
            make.center.equalToSuperview()
        }
        playPauseBtn.addTarget(self, action: #selector (playPauseButtonPressed), for: .touchUpInside)
        
        // add redo/undo button
        let undoBtn = UIButton(type:.custom)
        undoBtn.setImage(UIImage(systemName: "arrow.uturn.left"), for: .normal)
        bottomHeader.addSubview(undoBtn)
        
        let redoBtn = UIButton(type: .custom)
        redoBtn.setImage(UIImage(systemName: "arrow.uturn.right"), for: .normal)
        bottomHeader.addSubview(redoBtn)
        
        redoBtn.addTarget(self, action: #selector(redoButtonPressed), for: .touchUpInside)
        undoBtn.addTarget(self, action: #selector(undoButtonPressed), for: .touchUpInside)
        
        redoBtn.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(redoBtn.snp.height)
        }
        
        undoBtn.snp.makeConstraints { make in
            make.right.equalTo(redoBtn.snp.left).offset(-5)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(undoBtn.snp.height)
        }
        
        // add TimeLine View from TimeLineVC
        timeLineVC = TimeLineViewController()
        timeLineVC.project = project
        bottomView.addSubview(timeLineVC.view)
        
        timeLineVC.view.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(bottomHeader.snp.bottom)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
        
        timeLineVC.delegate = self
        
        // add a middle line
        let middleLine = UIView()
        timeLineVC.view.addSubview(middleLine)
        middleLine.backgroundColor = .white
        middleLine.isUserInteractionEnabled = false
        middleLine.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(30)
            make.width.equalTo(3)
            make.centerX.equalToSuperview()
        }
    }
    
    private func configurePlayerView() {
        playerView = UIView()
        self.view.addSubview(playerView)
        playerView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(headerView.snp.bottom)
            make.bottom.equalTo(bottomView.snp.top)
        }

        Task {
            // first make each edit asset
            let start = Date()
            let ok = try await project.createCompositionAsset()
            let end = Date()
            print("create composition asset time: \(end.timeIntervalSince(start))")
            
            if !ok {
                print("create composition asset failed")
                return
            }

            DispatchQueue.main.async {
                let playerItem = AVPlayerItem(asset: self.project.composition!)
                playerItem.videoComposition = self.project.videoComposition
                self.player = AVPlayer(playerItem: playerItem)
                self.playerLayer = AVPlayerLayer(player: self.player)
                self.playerLayer?.videoGravity = .resizeAspectFill
                self.playerView.layer.addSublayer(self.playerLayer!)
                self.playerLayer?.frame = self.playerView.bounds
                
                let timeInterval = CMTime(seconds: 0.03, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                
                self.timeObserverToken = self.player.addPeriodicTimeObserver(forInterval: timeInterval, queue: .main) { [weak self] time in
                    guard let self else { return }
                    Task { @MainActor in
                        self.playerTimeChagne(time: time)
                    }
                }
                
                self.timeLineVC.refreshData()
            }
            
            // export to cache dir for testing
//            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
//            let cacheUrl = cacheDir.appendingPathComponent("test.mp4")
//            
//            if FileManager.default.fileExists(atPath: cacheUrl.path) {
//                _ = try? FileManager.default.removeItem(at: cacheUrl)
//            }
//            
//            ok = try await project.export(to: cacheUrl)
//            if ok {
//                print("save the export to \(cacheUrl.path)")
//            } else {
//                print("export failed")
//            }
            
        }
    }
    
    private func configureVideoConfigureView() {
        let configureView = UIView()
        configureView.backgroundColor = .black
        self.view.addSubview(configureView)
        
        let optSlider1 = OptionSliderView(title: "Resolution", subtitle: "High definition", options: ["480P", "720P", "1080P", "2K", "4K"], defaultOptIndx: 2)
        configureView.addSubview(optSlider1)
        optSlider1.selectIdxCB = { [weak self] idx, opt in
            print("slider 1 selected")
        }
        
        let optSlider2 = OptionSliderView(title: "Frame Rate", subtitle: "Smoother playback", options: ["24", "25", "30", "50", "60"], defaultOptIndx: 2)
        configureView.addSubview(optSlider2)
        optSlider2.selectIdxCB = { [weak self] idx, opt in
            print("slider 2 selected")
        }
        
        let optSlider3 = OptionSliderView(title: "Bitrate(Mbps)", subtitle: "Recommded for this video", options: ["Low", "Recommended", "High"], defaultOptIndx:1)
        configureView.addSubview(optSlider3)
        optSlider3.selectIdxCB = { [weak self] idx, opt in
            print("slider 3 selected")
        }
        
        optSlider1.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview().inset(5)
        }
        
        optSlider2.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(5)
            make.top.equalTo(optSlider1.snp.bottom).offset(5)
        }
        
        optSlider3.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview().inset(5)
            make.top.equalTo(optSlider2.snp.bottom).offset(5)
        }
        
        configureView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(headerView.snp.top)
        }
        configureView.isHidden = true
        
        videoConfigureView = configureView
    }
    
    // MARK: utility
    private func playerTimeChagne(time: CMTime) {
        if player.rate == 0 {
            return
        }
        timeLineVC.setCurrentPlayTime(time)
    }
    
    // MARK: ui utility
    private func configureVideoConfigureButton(btn: UIButton, show: Bool)
    {
        var videoConfigureConfig = UIButton.Configuration.plain()
        videoConfigureConfig.title = "Video Configure"
        videoConfigureConfig.attributedTitle = AttributedString("1080P", attributes: AttributeContainer([.font: UIFont.boldSystemFont(ofSize: 16)]))
        videoConfigureConfig.baseForegroundColor = .white
        
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 8)
        if show {
            videoConfigureConfig.image = UIImage(systemName: "arrowtriangle.down.fill", withConfiguration: symbolConfig)
        } else {
            videoConfigureConfig.image = UIImage(systemName: "arrowtriangle.up.fill", withConfiguration: symbolConfig)
        }
        videoConfigureConfig.imagePlacement = .trailing
        videoConfigureConfig.imagePadding = 8
        
        btn.configuration = videoConfigureConfig
    }
    
    
    // MARK: events
    @objc func dismissBtnPressed() {
        if !videoConfigureView.isHidden {
            return
        }
        
        dismiss(animated: true)
        print("dismiss button pressed")
    }
    
    @objc func exportButtonPressed() {
        
    }
    
    @objc func scaleUpButtonPressed() {
        print("scale up button pressed")
    }
    
    @objc func scaleDownButtonPressed() {
        
    }

    @objc func playPauseButtonPressed() {
        if player.rate != 0 && player.error == nil {
            // is playing
            player.pause()
            playPauseBtn.setImage(UIImage(systemName: "play"), for: .normal)
        } else {
            if player.currentTime() == player.currentItem?.duration {
                player.seek(to: .zero)
            }
            playPauseBtn.setImage(UIImage(systemName: "pause"), for: .normal)
            player.play()
        }
    }
    
    @objc func redoButtonPressed() {
        print("redo button pressed")
    }
    
    @objc func undoButtonPressed() {
        print("undo button pressed")
    }
    
    @objc func videoCfgButtonPressed() {
        if videoConfigureView.isHidden {
            videoConfigureView.isHidden = false
            videoConfigureView.snp.remakeConstraints { make in
                make.left.right.equalToSuperview()
                make.top.equalTo(headerView.snp.bottom)
            }
            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            }
            configureVideoConfigureButton(btn: videoConfigBtn, show: false)
            // change the 'x' button to video button
            dismissBtn.setTitle("Video", for: .normal)
            dismissBtn.setImage(nil, for: .normal)
        } else {
            videoConfigureView.snp.remakeConstraints { make in
                make.left.right.equalToSuperview()
                make.bottom.equalTo(headerView.snp.top)
            }
            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.videoConfigureView.isHidden = true
            }
            configureVideoConfigureButton(btn: videoConfigBtn, show: true)
            // change the video button to the 'x' button
            dismissBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
            dismissBtn.setTitle(nil, for: .normal)
        }
    }
    
    //MARK: time line delegate
    func timeLineUserInteractiveTriggered() {
        // stop playing if it is playing
        if player.rate != 0 && player.error == nil {
            player.pause()
        }
        

    }
    
    func timeLineVideoIsPlaying() -> Bool {
        if player.rate != 0 && player.error == nil {
            return true
        }
        
        return false
    }
    
    func timeLineUserTriggeredTimeChange() {
        var curTime = timeLineVC.getCurrentTime()
        // boundary check, don't exceed the full duration
        if let duration = player.currentItem?.duration {
            if curTime > duration {
                curTime = duration
            }
            
            let tolerance: CMTime = CMTimeMake(value: 1, timescale: 10)
            player.seek(to: curTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { finished in
                if finished {
//                    print("seek to time \(curTime.seconds) finished")
                }
            }
        }
    }
    
    func timeLineEndDragingWillScrollToTime(_ time: CMTime) {
        var targetTime = time
        if let duration = player.currentItem?.duration {
            if targetTime > duration {
                targetTime = duration
            }
            
            let tolerance: CMTime = CMTimeMake(value: 1, timescale: 10)
            player.seek(to: targetTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { finished in
                if finished {
//                    print("seek to time \(targetTime.seconds) finished")
                }
            }
        }
    }
    
}



struct EditView_Preview: PreviewProvider {
    static var previews: some View {
        EditViewWrapper()
    }
}
