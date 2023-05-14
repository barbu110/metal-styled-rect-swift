#include <metal_stdlib>

#include "ShaderTypes.h"

using namespace metal;

struct RectFragmentData {
    float4 position [[position]];
    float2 rect_origin;
    float2 rect_size;
    float4 background_color;
    float4 border_size;
    float4 border_color;
    
    float corner_radius;
};

float4 to_device_position(float2 pixel_space_pos, float2 viewport_size) {
    float4 ndc_pos = float4(0.0, 0.0, 0.0, 1.0);
    ndc_pos.x = 2.0 * pixel_space_pos.x / viewport_size.x - 1.0;
    ndc_pos.y = 1.0 - 2.0 * pixel_space_pos.y / viewport_size.y;
    
    return ndc_pos;
}

vertex RectFragmentData
rect_vertex_shader(uint vertex_id [[vertex_id]],
                   constant float2 *vertices [[buffer(0)]],
                   constant PerRectUniforms *rect_uniforms [[buffer(1)]],
                   constant Uniforms *uniforms [[buffer(2)]]) {
    constant auto &v = vertices[vertex_id];
    float2 position = v * rect_uniforms->size + rect_uniforms->origin;

    return RectFragmentData {
        .position = to_device_position(position, uniforms->viewport_size),
        .rect_origin = rect_uniforms->origin,
        .rect_size = rect_uniforms->size,
        .border_size = rect_uniforms->border_size,
        .border_color = rect_uniforms->border_color,
        .background_color = rect_uniforms->background_color,
    };
}

fragment float4
rect_fragment_shader(RectFragmentData in [[stage_in]]) {
    float2 p = in.position.xy;
    float2 border_corner = in.rect_origin + in.rect_size;
    float2 border_origin = in.rect_origin;
    bool is_border = p.x <= (border_origin.x + in.border_size.w) || // left border
        p.x >= (border_corner.x - in.border_size.y) || // right broder
        p.y <= (border_origin.y + in.border_size.x) || // top border
        p.y >= (border_corner.y - in.border_size.z); // bottom border

    return is_border ? in.border_color : in.background_color;
}

