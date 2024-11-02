//
//  TimeLineView.swift
//  TimeLineVC
//
//  Created by Yu Yang on 2024-10-01.
//

import Foundation
import UIKit
import SwiftUI
import AVFoundation

struct TimeLineView : UIViewControllerRepresentable {
    //let vc = TimeLineViewController()
    let vc: TimeLineViewController = {
        var dm = TimeLineDataModel()
        // configure the data model
        configureDataModel(dm: &dm)
        
        var ret = TimeLineViewController()
        ret.model = dm
        return ret
    } ()
    
    func makeUIViewController(context: Context) -> some UIViewController {
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    private static func configureDataModel(dm: inout TimeLineDataModel)
    {
        configureVideoClips(dm: &dm)
        configureAudioClips(dm: &dm)
    }
    
    private static func configureVideoClips(dm: inout  TimeLineDataModel)
    {
        let duration1 = CMTime(value: 10, timescale: 1)
        let selectRange1 = CMTimeRange(start: CMTime(value: 1, timescale: 1), end: CMTime(value: 3, timescale: 1))
        let clip1 = Clip(duration: duration1, selectRange: selectRange1)
        
        let duration2 = CMTime(value: 12, timescale: 1)
        let selectRange2 = CMTimeRange(start: CMTime(value: 3, timescale: 1), end: CMTime(value: 10, timescale: 1))
        let clip2 = Clip(duration: duration2, selectRange: selectRange2)
        
        let duration3 = CMTime(value: 14, timescale: 1)
        let selectRange3 = CMTimeRange(start: CMTime(value: 4, timescale: 1), end: CMTime(value: 10, timescale: 1))
        let clip3 = Clip(duration: duration3, selectRange: selectRange3)

        dm.clips = [clip1, clip2, clip3]
    }
    
    private static func configureAudioClips(dm: inout TimeLineDataModel)
    {
        let duration1 = CMTime(value: 5, timescale: 1)
        let selectRange1 =  CMTimeRange(start: .zero, duration: duration1)
        let placeTime1 = CMTime(value: 2, timescale: 1)
        let clip1 = AudioClip(duration: duration1, selectRange: selectRange1, placeTime: placeTime1)
        
        let duration2 = CMTime(value: 6, timescale: 1)
        let selectRange2 = CMTimeRange(start: CMTime(value:2, timescale: 1), end: CMTime(value:4, timescale: 1))
        let placeTime2 = CMTime(value: 5, timescale: 1)
        let clip2 = AudioClip(duration: duration2, selectRange: selectRange2, placeTime: placeTime2)
        
        let duration3 = CMTime(value: 5, timescale: 1)
        let selectRange3 = CMTimeRange(start: CMTime(value: 3, timescale: 1), end: CMTime(value: 4, timescale: 1))
        let placeTime3 = CMTime(value: 8, timescale: 1)
        let clip3 = AudioClip(duration: duration3, selectRange: selectRange3, placeTime: placeTime3)
        
        dm.audioClips = [[clip1], [clip2, clip3]]
    }
}

protocol TimeLineControllerProtocol {
    // user interactive the time line view
    func timeLineUserInteractiveTriggered()
    func timeLineVideoIsPlaying() -> Bool
    func timeLineUserTriggeredTimeChange()
    func timeLineEndDragingWillScrollToTime(_ time: CMTime)
}

class TimeLineViewController : UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, TimeLineLayoutProtocol {
    
    var delegate: TimeLineControllerProtocol?
    
    private let clipRightDragViewTag = 1000
    private let clipLeftDragViewTag = 1001
    private let clipDragViewWidth: CGFloat = 20
    
    var collectionView: UICollectionView!
    
    var curLen: Float = 0
    var curTimeScale: Float = 0
    var curTimeScaleLen: Float = 0
    
    var selectClipPath: IndexPath?

    // states
    var model: TimeLineDataModel = TimeLineDataModel()
    
    // for gestures
    // for drag gesture
    var clipDragStartPos: CGPoint?
    var proposedLeftTimeOffset: CGFloat?
    var proposedRightTimeOffset: CGFloat?
    var isDragLeft: Bool?
    // for long press gesture
    var longPressTouchLoc: CGPoint?
    var longPressIndexPath: IndexPath?
    var longPressCurLoc: CGPoint? // for audio clip move
    
    var lastUpdateTime: Date?
    
    var timeLineLayout : TimeLineLayout!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let layout = TimeLineLayout()
        layout.delegate = self
        collectionView = UICollectionView(frame:view.bounds, collectionViewLayout: layout)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "timeIndicatorCell")
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "timeLineCell")
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "videoClipCell")
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "audioClipCell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .black
        timeLineLayout = layout
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressedGesture(_:)))
        collectionView.addGestureRecognizer(longPressGesture)
        
        let (_, maxLen) = model.getMaxMinLengthForTimeScale(scale: 1.0)
        curLen = maxLen
        curTimeScale = 1.0 // default is 1.0 second
        curTimeScaleLen = model.getSingleScaleLengthForTimeScale(len: curLen)
        
        view.addSubview(collectionView)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // only handle section >= 1 scenario
        if indexPath.section < 1 {
            return
        }
        
        let cell = collectionView.cellForItem(at: indexPath)
        // remove previous cell
        if let previousSelectPath = selectClipPath {
            
            let prevCell = collectionView.cellForItem(at: previousSelectPath)
            
            if let lv = prevCell?.contentView.viewWithTag(clipLeftDragViewTag) {
                lv.removeFromSuperview()
            }
            
            if let rv = prevCell?.contentView.viewWithTag(clipRightDragViewTag) {
                rv.removeFromSuperview()
            }
            
            if selectClipPath == indexPath {
                selectClipPath = nil
                return
            }
        }
        
        selectClipPath = indexPath
        // add collection view
        
        let contentView = cell!.contentView
        let height = cell!.contentView.frame.height
        // add left drag view
        let lv = UIView(frame: CGRectMake(0, 0, clipDragViewWidth, height))
        lv.tag = clipLeftDragViewTag
        lv.backgroundColor = .blue
        lv.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(lv)
        
        // add right drag view
        let rv = UIView(frame: CGRectMake(contentView.frame.width - clipDragViewWidth, 0, clipDragViewWidth, height))
        rv.tag = clipRightDragViewTag
        rv.backgroundColor = .blue
        rv.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rv)

        // add constraints
        NSLayoutConstraint.activate([
            lv.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            lv.widthAnchor.constraint(equalToConstant: clipDragViewWidth),
            lv.heightAnchor.constraint(equalToConstant: height),

            rv.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            rv.widthAnchor.constraint(equalToConstant: clipDragViewWidth),
            rv.heightAnchor.constraint(equalToConstant: height)
        ])
        
        lv.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDragGesture(_:))))
        rv.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDragGesture(_:))))
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        let audioSectionCnt = model.audioClips.count
        return 2 + audioSectionCnt
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            // the time mark
            let intervals = Int(ceil(model.videoDuration / curTimeScale))
            return intervals + 1
        }
        
        if section == 1 {
            return model.clips.count
        }
        
        if section > 1 {
            // audio items
            let rows = model.audioClips[section-2]
            
            if section == 2 && rows.count == 2 {
                print("stop here")
            }
            
            return rows.count
        }
        
        // this should not happen
        assert(false)
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.section == 0 {
            
            if indexPath.row > 0 {
                
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "timeLineCell", for: indexPath)
                // need to minus as the first item is the current time label
                let timeLabel =  String(format: "%.2f" ,Float(indexPath.row - 1) * curTimeScale)
                
                if let label = cell.contentView.viewWithTag(100) as? UILabel {
                    if indexPath.row % 2 == 0 {
                        label.text = timeLabel
                    } else {
                        label.text = "."
                    }
                } else {
                    // Add label to cell
                    let label0 = UILabel(frame: cell.contentView.bounds)
                    label0.tag = 100
                    label0.textAlignment = .center
                    label0.textColor = .white
                    if indexPath.row % 2 == 0 {
                        
                        label0.text = timeLabel
                    } else {
                        label0.text = "."
                    }
                    cell.contentView.addSubview(label0)
                    label0.snp.makeConstraints { (make) in
                        make.top.equalToSuperview()
                        make.centerX.equalToSuperview()
                    }
                }
                
                cell.contentView.backgroundColor = .blue
                return cell
            } else {
                // no reuse for this cell
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "timeIndicatorCell", for: indexPath)
                
                // add a label
                let label = UILabel(frame: cell.contentView.bounds)
                label.textAlignment = .center
                cell.contentView.addSubview(label)
                label.snp.makeConstraints { make in
                    make.top.equalToSuperview()
                    make.centerX.equalToSuperview()
                }
                
                label.text = getCurrentTimeLineTimeStr()
                label.textColor = .white
                
                // always at the top
                cell.layer.zPosition = 100
                cell.backgroundColor = .blue
                
                return cell
            }
            
            
        } else if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "videoClipCell", for: indexPath)
            cell.backgroundColor = .red
            
            cell.layer.borderWidth = 1
            cell.layer.borderColor = .init(red: 0, green: 1, blue: 0, alpha: 1)
            
            return cell
        } else {
            // the remaings are the audio clips
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "audioClipCell", for: indexPath)
            cell.backgroundColor = .yellow
            cell.layer.borderColor = .init(red: 0, green: 1, blue: 0, alpha: 1)
            cell.layer.borderWidth = 1
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return false
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath.section == 1 && destinationIndexPath.section == 1 {
            // video clip
            let idx1 = sourceIndexPath.row
            let idx2 = destinationIndexPath.row
            model.clips.swapAt(idx1, idx2)
        }
        
        if sourceIndexPath.section > 1 && destinationIndexPath.section > 1 {
            // audio clip
            print("debug here")
            
        }
    }
    
    //MARK: control
    func setCurrentPlayTime(_ time: CMTime)
    {
        let length1 = time.seconds / CGFloat(curTimeScale) * CGFloat(curTimeScaleLen)
        let targetX : CGFloat = length1 - collectionView.frame.width / 2.0 + timeLineLayout.timeLineXOffset
        collectionView.setContentOffset(CGPoint(x: targetX, y: 0), animated: false)
    }
    
    func getCurrentTime()->CMTime
    {
        // make sure the time is always >= 0 by set offset >= 0
        let offset = max(collectionView.contentOffset.x, 0)
        let time = (Float(offset) / curTimeScaleLen) * curTimeScale
        return CMTime(seconds: Double(time), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    }
    
    //MARK: timeline layout delegate
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        if indexPath.section == 0 {
            var width =  curTimeScaleLen
            if indexPath.row == 0 {
                width = 100 // fixed width
            }
            let s = CGSizeMake(CGFloat(width), 50)
            return s
        } else if indexPath.section == 1 {
            // video clip views
            let clip = model.clips[indexPath.row]
            let width = clip.getLength(timeScale: curTimeScale, timeScaleLen: curTimeScaleLen)
            let s = CGSizeMake(CGFloat(width), 50)
            return s
        } else {
            // audo clip views
            let audioClip = model.audioClips[indexPath.section - 2][indexPath.row]
            let width = audioClip.getLength(timeScale: curTimeScale, timeScaleLen: curTimeScaleLen)
            let s = CGSizeMake(CGFloat(width), 50)
            return s
        }
    }
    
    func getAudioItemPlaceInfo(indexPath: IndexPath) -> (CGFloat, CGSize) {
        guard indexPath.section > 1 else {
            assert(false)
        }
        
        let size = collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: indexPath)
        let clip = model.audioClips[indexPath.section - 2][indexPath.row]
        let x = clip.getPlaceX(timeScale: CGFloat(curTimeScale), timeScaleLen: CGFloat(curTimeScaleLen))
        
        return (x, size)
    }
    
    func getDragInformation(isLeftDrag: inout Bool, leftOffset: inout CGFloat, rightOffset: inout CGFloat, selectIndexPath: inout IndexPath) -> Bool {
        guard let selectClipPath else {
            return false
        }
        
        if proposedLeftTimeOffset == nil && proposedRightTimeOffset == nil {
            // no drag yet
            return false
        }
        
        assert((proposedLeftTimeOffset != nil && proposedRightTimeOffset == nil) || (proposedLeftTimeOffset == nil && proposedRightTimeOffset != nil))
        
        // adjust the offset
        isLeftDrag = isDragLeft!
        var left = proposedLeftTimeOffset
        var right = proposedRightTimeOffset
        var clip: Clip? = nil
        
        if selectClipPath.section == 1 {
            clip = model.clips[selectClipPath.row]
        } else {
            // section clips
            let secClips = model.audioClips[selectClipPath.section-2]
            secClips[selectClipPath.row].noOverlapAdjust(clips: secClips, leftTimeOffset: &left, rightTimeOffset: &right)
            clip = secClips[selectClipPath.row]
        }
        
        guard let clip else {
            assert(false, "no valid clip found for drag")
        }
        
        clip.adjustTimeOffset(leftTimeOffset: &left, rightTimeOffset: &right)
        if let left {
            leftOffset = left / CGFloat(curTimeScale) * CGFloat(curTimeScaleLen)
        }
        
        if let right {
            rightOffset = right / CGFloat(curTimeScale) * CGFloat(curTimeScaleLen)
        }
        
        selectIndexPath = selectClipPath
        return true
    }

    func getLongPressInformation(touchPos: inout CGPoint, touchIndexPath: inout IndexPath) -> Bool {
        guard let longPressTouchLoc, let longPressIndexPath else {
            return false
        }
        
        touchPos = longPressTouchLoc
        touchIndexPath = longPressIndexPath
        return true
    }
    
    func getLongPressAudioClipInformation(touchPos: inout CGPoint, curPos: inout CGPoint, indexPath: inout IndexPath) -> Bool {
        guard let longPressTouchLoc, let longPressIndexPath, let longPressCurLoc else {
            return false
        }
        
        touchPos = longPressTouchLoc
        curPos = longPressCurLoc
        indexPath = longPressIndexPath
        
        return true
    }
    
    //MARK: drag gesture recognizer
    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            delegate?.timeLineUserInteractiveTriggered()
        }
        
        if gesture.state == .changed {
            let scale = Float(gesture.scale)
            var newLen = curLen * scale
            newLen = min(model.maxLen, newLen)
            newLen = max(model.minLen, newLen)
            
            if curLen != newLen {
                curLen = newLen
                curTimeScale = model.getScaleForLength(len: curLen)
                curTimeScaleLen = model.getSingleScaleLengthForTimeScale(len: curLen)
                collectionView.reloadData()
                collectionView.collectionViewLayout.invalidateLayout()
            }
            
            gesture.scale = 1.0
            print("new length is \(newLen) scale is \(curTimeScale), single scale len \(curTimeScaleLen)")
        }
    }
    
    @objc func handleDragGesture(_ gesture: UIPanGestureRecognizer) {
        let viewTag = gesture.view!.tag
        assert(viewTag == clipLeftDragViewTag || viewTag == clipRightDragViewTag)
        let isLeftDrag = (viewTag == clipLeftDragViewTag) ? true: false
        
        switch gesture.state {
        case .began:
            clipDragStartPos = gesture.location(in: self.view)
        case .changed:
            let curPos = gesture.location(in: self.view)
            let offset = CGPointMake(curPos.x - clipDragStartPos!.x, curPos.y - clipDragStartPos!.y)
            dragUpdate(offset.x, isLeftDrag)
        case .ended, .cancelled:
            dragEnd(isLeftDrag)
        default:
            print("default")
        }
    }
    
    private func dragUpdate(_ xOffset: CGFloat, _ isLeftDrag: Bool) {
        guard let selectClipPath else {
            assert(false)
        }
        
        assert(selectClipPath.section >= 1)
        
        let timeOffset = (xOffset / CGFloat(curTimeScaleLen)) * CGFloat(curTimeScale)
        
        if isLeftDrag {
            if proposedLeftTimeOffset != nil && proposedLeftTimeOffset == timeOffset {
                return
            }
            
            // relayout
            proposedLeftTimeOffset = timeOffset
            proposedRightTimeOffset = nil
            isDragLeft = true
            collectionView.collectionViewLayout.invalidateLayout()
        } else {
            if proposedRightTimeOffset != nil && proposedRightTimeOffset == timeOffset {
                return
            }
            
            // relayout
            proposedLeftTimeOffset = nil
            proposedRightTimeOffset = timeOffset
            isDragLeft = false
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    private func dragEnd(_ isLeftDrag: Bool) {
        guard let selectClipPath else {
            assert(false)
        }
        
        if selectClipPath.section == 1 {
            // video clip
            let clip = model.clips[selectClipPath.row]
            clip.commitOffset(leftOffsetTime: proposedLeftTimeOffset, rightOffsetTime: proposedRightTimeOffset, isDragLeft: isDragLeft!)
        } else {
            // audio clip
            let secClips = model.audioClips[selectClipPath.section - 2]
            let audioClip = secClips[selectClipPath.row]
            audioClip.commitOffset(leftOffsetTime: proposedLeftTimeOffset, rightOffsetTime: proposedRightTimeOffset, isDragLeft: isDragLeft!, sectionClips: secClips)
        }
        collectionView.collectionViewLayout.invalidateLayout()
        
        proposedLeftTimeOffset = nil
        proposedRightTimeOffset = nil
        isDragLeft = nil
    }
    
    // MARK: long pressed gesture
    @objc func handleLongPressedGesture(_ gesture: UILongPressGestureRecognizer)
    {
        switch gesture.state {
        case .began:
            longPressBegan(gesture)
        case .changed:
            longPressChanged(gesture)
        case .ended:
            longPressEnd(gesture)
        default:
            self.collectionView.cancelInteractiveMovement()
        }
    }

    private func longPressBegan(_ gesture: UILongPressGestureRecognizer)
    {
        delegate?.timeLineUserInteractiveTriggered()
        
        let pos = gesture.location(in: collectionView)
        guard let selectIndexPath = collectionView.indexPathForItem(at: pos), selectIndexPath.section >= 1 else {
            return
        }
        print("touch at \(selectIndexPath)")
        
        longPressTouchLoc = pos
        longPressIndexPath = selectIndexPath
        
        let sectionIdx = selectIndexPath.section
        
        if sectionIdx == 1 {
            // for
            UIView.animate(withDuration: 0.2) {
                self.collectionView.performBatchUpdates {
                } completion: { finished in
                    if finished, let indexPath = self.longPressIndexPath {
                        let _ = self.collectionView.beginInteractiveMovementForItem(at: indexPath)
                    }
                }
            }
        } else {
            // audio clips, just record the current location
            longPressCurLoc = longPressTouchLoc
            
            // set high zindex for select index path view
            let cell = collectionView.cellForItem(at: selectIndexPath)
            cell?.layer.zPosition = 100
        }
    }
    
    private func longPressChanged(_ gesture: UILongPressGestureRecognizer)
    {
        guard let _ =  longPressTouchLoc, let indexPath = longPressIndexPath else {
            return
        }
        
        // get the first
        let curPos = gesture.location(in: collectionView)
        
        if indexPath.section == 1 {
            // TODO: replace the hard code 100
            self.collectionView.updateInteractiveMovementTargetPosition(CGPointMake(curPos.x, 75+25))
        } else {
            // audio clip
            longPressCurLoc = curPos
            // relayout
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    private func longPressEnd(_ gesture: UILongPressGestureRecognizer)
    {
        if let longPressIndexPath {
            if longPressIndexPath.section > 1 {
                // restore the z position of cell view to default
                let cell = collectionView.cellForItem(at: longPressIndexPath)
                cell?.layer.zPosition = 0
                // audio clip
                audioClipDrop(gesture)
            }
        }
        
        if longPressIndexPath?.section == 1 {
            longPressTouchLoc = nil
            longPressIndexPath = nil
            longPressCurLoc = nil
            
            self.collectionView.endInteractiveMovement()
            collectionView.collectionViewLayout.invalidateLayout()
        } else {
            longPressTouchLoc = nil
            longPressIndexPath = nil
            longPressCurLoc = nil
            // audio clip move end operation
            // simple re-layout
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    private func audioClipDrop(_ gesture: UILongPressGestureRecognizer)
    {
        guard let longPressIndexPath else {
            assert(false)
        }
        
        let pos = gesture.location(in: collectionView)
        
        guard let selectCell = collectionView.cellForItem(at: longPressIndexPath) else {
            return
        }
        
        let selectFrame = selectCell.frame
        
        var hasOverlap = false
        
        for cell in collectionView.visibleCells {
            if cell === selectCell {
                continue
            }
            
            let frame = cell.frame
            if CGRectIntersectsRect(frame, selectFrame) {
                hasOverlap = true
                break
            }
        }
        
        if hasOverlap {
            // don't allow overlap with any cell (include time line cell and video clip)
            print("move audio clip overlap with other cell, skip")
            return
        }
        
        // check if the current position is audio clip
        guard let layout = collectionView.collectionViewLayout as? TimeLineLayout else {
            assert(false, "not timeline layout")
        }
        
        var targetSec: Int?
        // for audio clips section only
        for sec in 2..<collectionView.numberOfSections {
            let (valid, minY, maxY) = layout.getSectionYBounds(sec: sec)
            if !valid {
                continue
            }
            if pos.y < minY || pos.y > maxY {
                continue
            }
            
            targetSec = sec
            break
        }
        
        guard let targetSec else {
            return
        }
        
        guard let layout = collectionView.collectionViewLayout as? TimeLineLayout else {
            assert(false)
        }
        
        let newX = selectFrame.origin.x - layout.timeLineXOffset
        let (origX, _) = getAudioItemPlaceInfo(indexPath: longPressIndexPath)
        let timeOffset = (newX - origX) / CGFloat(curTimeScaleLen) * CGFloat(curTimeScale)
        let audioClip = model.audioClips[longPressIndexPath.section-2][longPressIndexPath.row]
        let newPlaceTime = audioClip.placeTime.seconds + timeOffset
        // TODO: replace hard code number
        audioClip.placeTime = CMTime(seconds: newPlaceTime, preferredTimescale: 10000)
        
        if targetSec != longPressIndexPath.section {
            // need to update the data model
            model.audioClips[longPressIndexPath.section-2].removeAll(where: { $0 === audioClip })
            model.audioClips[targetSec-2].append(audioClip)
            // needs to refresh data source so collectionview.numberOfSection .. can be correct
            collectionView.reloadData()
        }
    }
    
    private var isDragging: Bool = false
    //MARK: scroll delegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // only dealing when the player is not playing
        if let delegate, !delegate.timeLineVideoIsPlaying() {
            if (isDragging) {
                // will try to reduce the time to trigger time change to avoid performance issue
                if lastUpdateTime == nil {
                    delegate.timeLineUserTriggeredTimeChange()
                    lastUpdateTime = Date()
                } else {
                    let curTime = Date()
                    if curTime.timeIntervalSince(lastUpdateTime!) > 0.15 {
                        delegate.timeLineUserTriggeredTimeChange()
                        lastUpdateTime = curTime
                    }
                }
            }
        }
        
        if !isDragging {
            print(scrollView.contentOffset.x)
        }
        
        // need to relayout the collection view
        collectionView.collectionViewLayout.invalidateLayout()
        
        // update the time label
        let timeCell = collectionView.cellForItem(at: IndexPath(row: 0, section: 0))
        if let label = timeCell?.contentView.subviews.first as? UILabel {
            label.text = getCurrentTimeLineTimeStr()
        }
        
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.timeLineUserInteractiveTriggered()
        isDragging = true
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        isDragging = false
        
        guard let layout = collectionView.collectionViewLayout as? TimeLineLayout else {
            assert(false)
        }
        
        let startOffset = layout.timeLineXOffset
        
        let middleOffset = targetContentOffset.pointee.x + scrollView.bounds.width / 2 - startOffset
        let targetTime = middleOffset / CGFloat(curTimeScaleLen) * CGFloat(curTimeScale)
        let cmTargetTime = CMTime(seconds: Double(targetTime), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        delegate?.timeLineEndDragingWillScrollToTime(cmTargetTime)
        
        print("target offset is \(targetContentOffset.pointee.x)")
    }
    
    
    //MARK: - utility
    func getCurrentTimeLineTimeStr() -> String {
        let time = getCurrentTime()
        
        let minutes = Int(time.seconds / 60)
        let seconds = Int(time.seconds.truncatingRemainder(dividingBy: 60))
        let timeStr = String(format: "%02d:%02d", minutes, seconds)
        return timeStr
    }
}
