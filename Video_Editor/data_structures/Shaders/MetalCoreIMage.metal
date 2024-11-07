//
//  MetalCoreIMage.metal
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-07.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h> // includes CIKernelMetalLib.h
#include <SwiftUI/SwiftUI.h>

using namespace metal;

[[ stitchable ]]
half4 radiusTransitionFilter(coreimage::sampler frontImage, coreimage::sampler backgroundImage, float percent)
{
    float2 size = frontImage.size();
    
    float2 position = frontImage.coord();
    position = float2(position.x * size.x, position.y * size.y);
    
    float2 center = float2(size.x / 2, size.y / 2);
    
    float2 v1 = position - center;
    // horizental vector
    float2 v2 = float2(1, 0);
    
    float angle = atan2(v1.y, v1.x);
    angle = angle >= 0? angle: (angle + 2 * M_PI_F);
    
    float thresholdAngle = percent * 2 * M_PI_F;
    if (angle > thresholdAngle) {
        return half4(backgroundImage.sample(frontImage.coord()));
    } else {
        return half4(frontImage.sample(backgroundImage.coord()));
    }
}
