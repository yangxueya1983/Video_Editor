//
//  EditAssert.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation

class EditAsset {
    let id = UUID()
}

class VisualEditAsset: EditAsset {

}

class AudioEditAsset: EditAsset {

}

class PhotoEditAsset : VisualEditAsset {

}

class VideoEditAsset: VisualEditAsset {
    
}
