#include <metal_stdlib>
using namespace metal;

// For hardcoded triangle (original test)
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

// For vertex buffer rendering
struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 modelMatrix;     // 64 bytes
    float4x4 viewMatrix;      // 64 bytes
    float4x4 projectionMatrix; // 64 bytes
    float time;               // 4 bytes
    float3 padding;           // 12 bytes
    float4 padding2;          // 16 bytes more to match Swift's 224
};  // Total: 224 bytes to match Swift

vertex VertexOut simpleVertexBufferShader(VertexIn in [[stage_in]],
                                          constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;

    float4 position = float4(in.position, 1.0);
    float4 worldPos = uniforms.modelMatrix * position;
    float4 viewPos = uniforms.viewMatrix * worldPos;
    out.position = uniforms.projectionMatrix * viewPos;
    out.color = in.color;

    return out;
}

fragment float4 simpleFragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}