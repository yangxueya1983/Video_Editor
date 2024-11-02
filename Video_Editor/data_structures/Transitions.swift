//
//  Transitions.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-02.
//

import Foundation

enum TransitionType : Int {
    case None
}

struct VideoTransition {
    let type: TransitionType
    let fromAssetID: UUID
    let toAssetID: UUID
}


