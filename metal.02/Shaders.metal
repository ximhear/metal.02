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
                              constant Uniforms& uniforms [[buffer(1)]],
                              uint vertexID [[vertex_id]]) {
    
    VertexOut out;
//    float4 position = float4(in.position, 1.0);
//    float4 position = float4(in.position * ((cos(uniforms.time) + 1)/2.0 / 2.0 + 0.5), 1.0);
    float4 position = float4(in.position * (cos(uniforms.time) / 4.0 + 0.75), 1.0);
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * position;
    
    // 기본 색상들 정의 (Red, Green, Blue)
    float4 colors[3] = {
        float4(1.0, 0.0, 0.0, 1.0), // Red
        float4(0.0, 1.0, 0.0, 1.0), // Green
        float4(0.0, 0.0, 1.0, 1.0)  // Blue
    };
    
    // 시간에 따라 색상 인덱스를 순환시킴
    float colorCycle = uniforms.time * 0.5; // 속도 조절
    int colorIndex = int(floor(colorCycle + vertexID)) % 3;
    int nextColorIndex = (colorIndex + 1) % 3;
    
    // 색상 간 보간을 위한 팩터 계산
    float interpolationFactor = fract(colorCycle);
    
    // 현재 색상과 다음 색상을 보간
    out.color = mix(colors[colorIndex], colors[nextColorIndex], interpolationFactor);
    out.color = in.color; // 기존 색상 유지

    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]], constant Uniforms& uniforms [[buffer(0)]]) {
    return in.color;
}
