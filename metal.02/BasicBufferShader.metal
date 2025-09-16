#include <metal_stdlib>
using namespace metal;

// Minimal vertex buffer test
struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut basicVertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    // Just pass through position without any transformation
    out.position = float4(in.position, 1.0);
    out.color = in.color;
    return out;
}

fragment float4 basicFragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}