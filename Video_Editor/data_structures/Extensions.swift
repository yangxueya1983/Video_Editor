//
//  extensions.swift
//  TimeLineVC
//
//  Created by Yu Yang on 2024-10-19.
//

import SwiftUI
import UIKit

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(red: Int, green: Int, blue: Int, opacity: Double) {
        self.init(
            red: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: opacity
        )
    }
    
    convenience init?(hex: String) {
        var cleanedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Remove the leading "#" if it exists
        if cleanedHex.hasPrefix("#") {
            cleanedHex.remove(at: cleanedHex.startIndex)
        }

        // The hex code must be exactly 6 or 8 characters
        guard cleanedHex.count == 6 || cleanedHex.count == 8 else {
            return nil
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cleanedHex).scanHexInt64(&rgbValue)

        if cleanedHex.count == 6 {
            // RGB (Hex value)
            let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            let blue = CGFloat(rgbValue & 0x0000FF) / 255.0

            self.init(red: red, green: green, blue: blue, alpha: 1.0)
        } else if cleanedHex.count == 8 {
            // RGBA (Hex value)
            let alpha = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            let red = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            let green = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            let blue = CGFloat(rgbValue & 0x000000FF) / 255.0

            self.init(red: red, green: green, blue: blue, alpha: alpha)
        } else {
            return nil
        }
    }
}
