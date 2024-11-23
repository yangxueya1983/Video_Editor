//
//  TimeLineLayout.swift
//  TimeLineVC
//
//  Created by Yu Yang on 2024-10-03.
//

import Foundation
import UIKit

struct TimeLineLayoutConfig {
    static let longPressFixedWidth : CGFloat = 50
}

@MainActor
protocol TimeLineLayoutProtocol {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    
    func getDragInformation(isLeftDrag: inout Bool,  leftOffset: inout CGFloat, rightOffset: inout CGFloat, selectIndexPath: inout IndexPath) -> Bool
    
    // for video clip
    func getLongPressInformation(touchPos: inout CGPoint, touchIndexPath: inout IndexPath) -> Bool
    
    func getAudioItemPlaceInfo(indexPath: IndexPath) -> (CGFloat, CGSize)
    func getLongPressAudioClipInformation(touchPos: inout CGPoint, curPos: inout CGPoint, indexPath: inout IndexPath) -> Bool
}

class TimeLineLayout : UICollectionViewLayout {
    var delegate : TimeLineLayoutProtocol?
    
    var contentSize = CGSizeZero
    var previousAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    var currentAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    var timeLineXOffset : CGFloat = 0
    
    override func prepare() {
        super.prepare()
        
        guard let collectionView, let delegate else {
            return
        }
        
        previousAttributes = currentAttributes
        currentAttributes.removeAll()
        
        let secNum = collectionView.numberOfSections
        var maxHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        // for offset the length created by timeline
        // item 0 is the current time label, should use item 1
        let xOffset = collectionView.frame.width / 2 - delegate.collectionView(collectionView, layout: self, sizeForItemAt: IndexPath(item: 1, section: 0)).width/2
        
        timeLineXOffset = xOffset
        
        // TODO: replace the hardcode number
        var audioY : CGFloat = 75 + 50 + 10
        
        for sec in 0..<secNum {
            if sec == 0 {
                // section 0 layout
                // suppose the size should be the same for all index paths
                let size = delegate.collectionView(collectionView, layout: self, sizeForItemAt: IndexPath(item: 1, section: 0))
                let itemCnt = collectionView.numberOfItems(inSection: 0)
                
                // item 0 is special cell for displaying the current time / total time
                var offset: CGFloat = timeLineXOffset
                for itmIdx in 1..<itemCnt {
                    let indexPath = IndexPath(row: itmIdx, section: 0)
                    let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                    
                    attributes.frame = CGRectMake(offset, 0, size.width, size.height)
                    currentAttributes[indexPath] = attributes
                    offset += size.width
                }
                maxWidth = max(maxWidth, offset)
                maxHeight = max(maxHeight, 50)
                
                // add padding so that the total time
                maxWidth += collectionView.frame.width / 2 - size.width/2
                
                // special handing for item 0
                let width = delegate.collectionView(collectionView, layout: self, sizeForItemAt: IndexPath(item: 0, section: 0)).width
                let contentOffsetX = collectionView.contentOffset.x
                let indexPath = IndexPath(row: 0, section: 0)
                let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attribute.frame = CGRectMake(contentOffsetX, 0, width, size.height)
                currentAttributes[indexPath] = attribute
            }
            
            if sec == 1 {
                let yOffset:CGFloat = 75
                // clips layout
                let itemCnt = collectionView.numberOfItems(inSection: 1)
                
                // get drag information
                var leftOffset: CGFloat = 0
                var rightOffset: CGFloat = 0
                var isDragLeft: Bool = false
                var dragIndexPath: IndexPath = .init()
                
                let hasDrag = delegate.getDragInformation(isLeftDrag: &isDragLeft, leftOffset: &leftOffset, rightOffset: &rightOffset, selectIndexPath: &dragIndexPath)
                
                if hasDrag && dragIndexPath.section == 1 {
                    // layout for the drag
                    if isDragLeft {
                        // calculate the drag clip right position
                        var x : CGFloat = xOffset
                        for itemIdx in 0...dragIndexPath.row {
                            let indexPath = IndexPath(row: itemIdx, section: 1)
                            let size = delegate.collectionView(collectionView, layout: self, sizeForItemAt: indexPath)
                            x += size.width
                        }
                        
                        // layout item > drag index
                        var rightItemX = x
                        for itemIdx in (dragIndexPath.row + 1)..<itemCnt {
                            let indexPath = IndexPath(row: itemIdx, section: 1)
                            let size = delegate.collectionView(collectionView, layout: self, sizeForItemAt: indexPath)
                            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                            attributes.frame = CGRectMake(rightItemX, yOffset, size.width, size.height)
                            currentAttributes[indexPath] = attributes
                            maxHeight = max(maxHeight, yOffset + size.height)
                            maxWidth = max(maxWidth, rightItemX + xOffset + size.width)
                            rightItemX += size.width
                        }
                        
                        // layout item < drag index
                        maxWidth = max(maxWidth, x)
                        for itemIdx in stride(from: dragIndexPath.row, through: 0, by: -1) {
                            let indexPath = IndexPath(row: itemIdx, section: 1)
                            var size = delegate.collectionView(collectionView, layout: self, sizeForItemAt: indexPath)
                            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                            if itemIdx == dragIndexPath.row {
                                // positive left offset means larger start time (less duration)
                                size.width = size.width - leftOffset
                            }
                            
                            attributes.frame = CGRectMake(x - size.width, yOffset, size.width, size.height)
                            currentAttributes[indexPath] = attributes
                            maxHeight = max(maxHeight, size.height)
                            x -= size.width
                        }
                        
                    } else {
                        // right drag
                        var x: CGFloat = 0
                        for itemIdx in 0..<itemCnt {
                            let indexPath = IndexPath(row: itemIdx, section: 1)
                            let size = delegate.collectionView(collectionView, layout: self, sizeForItemAt: indexPath)
                            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                            if itemIdx < dragIndexPath.row {
                                // use original behavior
                                attributes.frame = CGRectMake(x + xOffset, yOffset, size.width, size.height)
                                x += size.width
                            } else if itemIdx == dragIndexPath.row {
                                attributes.frame = CGRectMake(x + xOffset, yOffset, size.width + rightOffset, size.height)
                                x += size.width + rightOffset
                            } else {
                                // add the right offset
                                attributes.frame = CGRectMake(x + xOffset, yOffset, size.width, size.height)
                                x += size.width
                            }
                            currentAttributes[indexPath] = attributes
                        }
                    }
                    
                } else {
                    // long press information
                    var lpLoc: CGPoint = .zero
                    var lpIndexPath = IndexPath(row: 0, section: 0)
                    let hasLongPress = delegate.getLongPressInformation(touchPos: &lpLoc, touchIndexPath: &lpIndexPath)
                    
                    if hasLongPress && lpIndexPath.section == 1 {
                        let fixWidth = TimeLineLayoutConfig.longPressFixedWidth
                        // use the same height
                        let fixHeight = delegate.collectionView(collectionView, layout: self, sizeForItemAt: IndexPath(row:0, section: 1)).height
                        // for long press indexPath
//                        let x = lpLoc.x + TimeLineLayoutConfig.longPressFixedWidth/2
                        // create the frames for all the item
                        var itemFrames: [CGRect] = Array(repeating: .zero, count: itemCnt)
                        itemFrames[lpIndexPath.row] = CGRectMake(lpLoc.x - fixWidth/2, yOffset, fixWidth, fixHeight)
                        
                        var x:CGFloat = lpLoc.x + fixWidth/2
                        for itemIdx in (lpIndexPath.row + 1)..<itemCnt {
                            itemFrames[itemIdx] = CGRectMake(x, yOffset, fixWidth, fixHeight)
                            x += fixWidth
                        }
                        
                        x = lpLoc.x - fixWidth/2 - fixWidth
                        for itemIdx in stride(from: lpIndexPath.row - 1, through: 0, by: -1) {
                            itemFrames[itemIdx] = CGRectMake(x, yOffset, fixWidth,fixHeight)
                            x = x - fixWidth
                        }
                        
                        for (idx, frame) in itemFrames.enumerated() {
                            let indexPath = IndexPath(row: idx, section: 1)
                            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                            attributes.frame = frame
                            currentAttributes[indexPath] = attributes
                            maxWidth = max(maxWidth, frame.origin.x + frame.width)
                            maxHeight = max(maxHeight, yOffset + frame.size.height)
                        }
                    } else {
                        // it starts at the center of collection view
                        var x: CGFloat = collectionView.frame.width/2
                        // no drag information
                        for itemIdx in 0..<itemCnt {
                            let indexPath = IndexPath(row:itemIdx, section: 1)
                            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                            
                            let size = delegate.collectionView(collectionView, layout: self, sizeForItemAt: indexPath)
                            attributes.frame = CGRectMake(x, yOffset, size.width, size.height)
                            currentAttributes[indexPath] = attributes
                            x += size.width
                            maxWidth = max(maxWidth, x)
                            maxHeight = max(maxHeight, yOffset + size.height)
                        }
                    }
                }
            }
            
            if sec > 1 {
                let frames = getAudioFrames(section: sec, xOffset: xOffset, yOffset: audioY)
                for (idx, frame) in frames.enumerated() {
                    let indexPath = IndexPath(row: idx, section: sec)
                    let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                    attributes.frame = frame
                    currentAttributes[indexPath] = attributes
                }
                audioY += 50 + 10 // item height + gap
            }
            
        }
        
        contentSize = CGSizeMake(maxWidth, maxHeight)
    }
    
    private func getAudioFrames(section: Int, xOffset: CGFloat, yOffset: CGFloat) -> [CGRect] {
        guard let collectionView, let delegate else {
            assert(false)
        }

        var leftOffset: CGFloat = 0
        var rightOffset: CGFloat = 0
        var isDragLeft = false
        var dragIndexPath: IndexPath = .init()
        
        let hasDrag = delegate.getDragInformation(isLeftDrag: &isDragLeft, leftOffset: &leftOffset, rightOffset: &rightOffset, selectIndexPath: &dragIndexPath)
        
        // the below API is not reliable when interactive move
        let itemCnt = collectionView.numberOfItems(inSection: section)
        
        if !hasDrag || dragIndexPath.section != section {
            // check long press
            var lpIniPos: CGPoint = .zero
            var lpCurPos: CGPoint = .zero
            var lpIdxPath: IndexPath = .init()
            let hasLp = delegate.getLongPressAudioClipInformation(touchPos: &lpIniPos, curPos: &lpCurPos, indexPath: &lpIdxPath)
            
            var ret: [CGRect] = []
            // normal layout
            for idx in 0..<itemCnt {
                let indexPath = IndexPath(row: idx, section: section)
                
                let (x, size) = delegate.getAudioItemPlaceInfo(indexPath: indexPath)
                if hasLp && lpIdxPath == indexPath {
                    let offset = CGPointMake(lpCurPos.x - lpIniPos.x, lpCurPos.y - lpIniPos.y)
                    ret.append(CGRectMake(x + xOffset + offset.x, yOffset + offset.y, size.width, size.height))
                } else {
                    ret.append(CGRectMake(x + xOffset, yOffset, size.width, size.height))
                }
            }
            return ret
        }
        
        // section has drag item
        var frames: [CGRect] = Array(repeating: .zero, count: itemCnt)
        
        // items not in drag are in the original position
        for idx in 0..<itemCnt {
            let indexPath = IndexPath(row: idx, section: section)
            let (x, size) = delegate.getAudioItemPlaceInfo(indexPath: indexPath)
            frames[idx] = CGRectMake(x + xOffset, yOffset, size.width, size.height)
        }
        
        var (x, size) = delegate.getAudioItemPlaceInfo(indexPath: dragIndexPath)
        // for drag items
        if isDragLeft {
            // left drag
            size.width -= leftOffset
            frames[dragIndexPath.row] = CGRectMake(x + xOffset + leftOffset, yOffset, size.width, size.height)
        } else {
            // right drag
            size.width += rightOffset
            frames[dragIndexPath.row] = CGRectMake(x + xOffset, yOffset, size.width, size.height)
        }
        
        return frames
    }
    
    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return previousAttributes[itemIndexPath]
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return currentAttributes[indexPath]
    }
    
    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return layoutAttributesForItem(at: itemIndexPath)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let f = currentAttributes.filter { CGRectIntersectsRect(rect, $0.value.frame)}
        return Array(f.values)
    }
    
    override var collectionViewContentSize: CGSize {
        return contentSize
    }
    
    // return (hasValue, low y, high y)
    func getSectionYBounds(sec: Int) -> (Bool, CGFloat, CGFloat)  {
        guard let collectionView else {
            return (false, 0, 0)
        }
        
        if sec >= collectionView.numberOfSections {
            return (false, 0, 0)
        }
        let itemCnt = collectionView.numberOfItems(inSection: sec)
        if itemCnt == 0 {
            return (false, 0, 0)
        }
        
        let indexPath = IndexPath(row: 0, section: sec)
        guard let attr = currentAttributes[indexPath] else {
            return (false, 0, 0)
        }
        
        return (true, attr.frame.origin.y, attr.frame.origin.y + attr.frame.size.height)
    }
}
