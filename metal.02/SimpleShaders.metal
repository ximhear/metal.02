#include <metal_stdlib>
using namespace metal;

struct SimpleVertex {
    float4 position [[position]];
    float4 color;
};

vertex SimpleVertex simpleVertexShader(uint vertexID [[vertex_id]]) {
    const float2 positions[3] = {
        float2(-0.5, -0.5),
        float2( 0.5, -0.5),
        float2( 0.0,  0.5)
    };

    const float4 colors[3] = {
        float4(1, 0, 0, 1),
        float4(0, 1, 0, 1),
        float4(0, 0, 1, 1)
    };

    SimpleVertex out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.color = colors[vertexID];
    return out;
}

fragment float4 simpleFragmentShader(SimpleVertex in [[stage_in]]) {
    return in.color;
}