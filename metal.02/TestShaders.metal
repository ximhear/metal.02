#include <metal_stdlib>
using namespace metal;

// Test with simple pass-through
vertex float4 testVertexShader(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2( 0.0,  0.5),
        float2(-0.5, -0.5),
        float2( 0.5, -0.5)
    };
    return float4(positions[vertexID], 0.0, 1.0);
}

fragment float4 testFragmentShader() {
    return float4(1.0, 0.0, 0.0, 1.0);  // Red
}