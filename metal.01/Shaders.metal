#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float time;
};

vertex VertexOut vertexShader(Vertex in [[stage_in]],
                              constant Uniforms& uniforms [[buffer(1)]]) {
    
    VertexOut out;
    float4 position = float4(in.position * cos(uniforms.time), 1.0);
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * position;
//    out.color = in.color;
    out.color = (in.color * sin(uniforms.time) + 1.0) * 0.5;

    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]], constant Uniforms& uniforms [[buffer(0)]]) {
    return in.color;
}
