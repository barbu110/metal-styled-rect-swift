//
//  ShaderTypes.h
//  metal-rectangle-swift
//
//  Created by Victor Barbu on 13.05.2023.
//

#include <simd/simd.h>

#ifndef ShaderTypes_h
#define ShaderTypes_h

struct PerRectUniforms {
    vector_float2 size;
    vector_float2 origin;
    vector_float4 background_color;
    
    /* Borders */
    
    vector_float4 border_size; // (top, right, bottom, left)
    vector_float4 border_color;
    
    float corner_radius;
};

struct Uniforms {
    vector_float2 viewport_size;
};

#endif /* ShaderTypes_h */
