#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float3 normal [[attribute(2)]];
    float2 texCoord [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float3 normal;
    float3 worldPosition;
    float2 texCoord;
    float3 viewDirection;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float time;
    float3 cameraPosition;
    float particleSize;
};

struct Light {
    float3 position;
    float3 color;
    float intensity;
};

// Noise functions for procedural effects
float random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

float noise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);

    float a = random(i);
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));

    float2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Main vertex shader with wave distortion
vertex VertexOut vertexShader(Vertex in [[stage_in]],
                              constant Uniforms& uniforms [[buffer(1)]],
                              uint vertexID [[vertex_id]]) {

    VertexOut out;

    // Wave distortion effect
    float wave = sin(uniforms.time * 2.0 + in.position.x * 3.0) * 0.1;
    float wave2 = cos(uniforms.time * 1.5 + in.position.y * 2.0) * 0.1;
    float3 distortedPosition = in.position;
    distortedPosition.z += wave + wave2;

    // Pulsating scale effect
    float pulse = 1.0 + sin(uniforms.time * 3.0) * 0.1;
    distortedPosition *= pulse;

    float4 position = float4(distortedPosition, 1.0);
    float4 worldPos = uniforms.modelMatrix * position;
    float4 viewPos = uniforms.viewMatrix * worldPos;

    out.position = uniforms.projectionMatrix * viewPos;
    out.worldPosition = worldPos.xyz;

    // Transform normal to world space
    float3x3 normalMatrix = float3x3(uniforms.modelMatrix[0].xyz,
                                      uniforms.modelMatrix[1].xyz,
                                      uniforms.modelMatrix[2].xyz);
    out.normal = normalize(normalMatrix * in.normal);

    // Calculate view direction
    out.viewDirection = normalize(uniforms.cameraPosition - worldPos.xyz);

    // Animated color based on position and time
    float colorPhase = uniforms.time + length(in.position) * 2.0;
    out.color = float4(
        sin(colorPhase) * 0.5 + 0.5,
        sin(colorPhase + 2.094) * 0.5 + 0.5,
        sin(colorPhase + 4.189) * 0.5 + 0.5,
        1.0
    );

    out.texCoord = in.texCoord;

    return out;
}

// Particle vertex shader
vertex VertexOut particleVertexShader(Vertex in [[stage_in]],
                                      constant Uniforms& uniforms [[buffer(1)]],
                                      uint instanceID [[instance_id]]) {
    VertexOut out;

    // Create particle animation
    float particleTime = uniforms.time + float(instanceID) * 0.1;
    float3 particlePos = in.position;

    // Spiral motion
    float angle = particleTime * 2.0 + float(instanceID) * 0.5;
    float radius = 2.0 + sin(particleTime * 0.5) * 0.5;
    particlePos.x += cos(angle) * radius;
    particlePos.z += sin(angle) * radius;
    particlePos.y += sin(particleTime * 3.0) * 1.5;

    float4 position = float4(particlePos * uniforms.particleSize, 1.0);
    float4 worldPos = uniforms.modelMatrix * position;

    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.worldPosition = worldPos.xyz;
    out.normal = float3(0, 1, 0);
    out.viewDirection = normalize(uniforms.cameraPosition - worldPos.xyz);

    // Particle color animation
    float hue = fract(particleTime * 0.1 + float(instanceID) * 0.05);
    out.color = float4(
        sin(hue * 6.28318) * 0.5 + 0.5,
        sin((hue + 0.333) * 6.28318) * 0.5 + 0.5,
        sin((hue + 0.666) * 6.28318) * 0.5 + 0.5,
        1.0 - fract(particleTime * 0.5)
    );

    out.texCoord = in.texCoord;

    return out;
}

// Advanced fragment shader with lighting and effects
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms& uniforms [[buffer(0)]]) {
    // Multiple light sources
    Light lights[3];
    lights[0].position = float3(5.0 * cos(uniforms.time), 3.0, 5.0 * sin(uniforms.time));
    lights[0].color = float3(1.0, 0.9, 0.8);
    lights[0].intensity = 1.2;

    lights[1].position = float3(-3.0, 2.0 * sin(uniforms.time * 1.5), -3.0);
    lights[1].color = float3(0.8, 0.4, 1.0);
    lights[1].intensity = 0.8;

    lights[2].position = float3(0.0, -2.0, 2.0 * cos(uniforms.time * 0.7));
    lights[2].color = float3(0.4, 1.0, 0.8);
    lights[2].intensity = 0.6;

    // Calculate lighting
    float3 finalColor = float3(0.0);
    float3 ambient = in.color.rgb * 0.2;

    for (int i = 0; i < 3; i++) {
        float3 lightDir = normalize(lights[i].position - in.worldPosition);

        // Diffuse lighting
        float diff = max(dot(in.normal, lightDir), 0.0);
        float3 diffuse = diff * lights[i].color * lights[i].intensity;

        // Specular lighting
        float3 reflectDir = reflect(-lightDir, in.normal);
        float spec = pow(max(dot(in.viewDirection, reflectDir), 0.0), 32.0);
        float3 specular = spec * lights[i].color * lights[i].intensity * 0.5;

        // Rim lighting
        float rim = 1.0 - max(dot(in.viewDirection, in.normal), 0.0);
        rim = pow(rim, 2.0);
        float3 rimLight = rim * lights[i].color * 0.3;

        finalColor += (diffuse + specular + rimLight) * in.color.rgb;
    }

    finalColor += ambient;

    // Add noise-based color variation
    float noiseValue = noise(in.worldPosition.xy * 5.0 + uniforms.time);
    finalColor += float3(noiseValue * 0.05);

    // Fresnel effect
    float fresnel = pow(1.0 - dot(in.viewDirection, in.normal), 2.0);
    finalColor += float3(0.2, 0.3, 0.5) * fresnel;

    // HDR tone mapping
    finalColor = finalColor / (finalColor + float3(1.0));

    // Gamma correction
    finalColor = pow(finalColor, float3(1.0/2.2));

    return float4(finalColor, in.color.a);
}

// Glow effect fragment shader
fragment float4 glowFragmentShader(VertexOut in [[stage_in]],
                                   constant Uniforms& uniforms [[buffer(0)]]) {
    // Animated glow effect
    float glowIntensity = sin(uniforms.time * 3.0) * 0.5 + 0.5;
    float3 glowColor = in.color.rgb * (1.0 + glowIntensity * 2.0);

    // Add edge glow
    float edge = 1.0 - abs(dot(in.viewDirection, in.normal));
    edge = pow(edge, 0.5);
    glowColor += float3(0.5, 0.8, 1.0) * edge * glowIntensity;

    // Pulse effect based on distance from center
    float distance = length(in.worldPosition.xz);
    float pulse = sin(distance * 2.0 - uniforms.time * 5.0) * 0.5 + 0.5;
    glowColor *= (0.5 + pulse * 0.5);

    return float4(glowColor, in.color.a);
}

// Hologram effect shader
fragment float4 hologramFragmentShader(VertexOut in [[stage_in]],
                                       constant Uniforms& uniforms [[buffer(0)]]) {
    // Scanline effect
    float scanline = sin(in.worldPosition.y * 50.0 + uniforms.time * 10.0);
    scanline = smoothstep(0.0, 0.1, scanline);

    // Hologram color
    float3 holoColor = float3(0.0, 0.8, 1.0);

    // Glitch effect
    float glitch = random(float2(uniforms.time * 0.1, in.worldPosition.y * 0.1));
    if (glitch > 0.95) {
        holoColor = float3(1.0, 0.0, 0.3);
    }

    // Edge highlight
    float edge = 1.0 - abs(dot(in.viewDirection, in.normal));
    edge = pow(edge, 0.3);

    // Combine effects
    float3 finalColor = holoColor * edge * (0.5 + scanline * 0.5);

    // Add noise
    float noiseValue = noise(in.worldPosition.xy * 10.0 + uniforms.time * 2.0);
    finalColor += holoColor * noiseValue * 0.2;

    // Transparency based on viewing angle
    float alpha = edge * 0.8 + 0.2;

    return float4(finalColor, alpha * scanline);
}