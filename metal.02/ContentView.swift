//
//  ContentView.swift
//  metal.02
//
//  Created by gzonelee on 9/10/25.
//

import SwiftUI

struct ContentView: View {
    @State private var projectionMode: MetalView.ProjectionMode = .perspective
    @State private var renderMode: MetalView.RenderMode = .combined
    @State private var showDebugInfo: Bool = false
    @State private var particleCount: Double = 100
    @State private var rotationSpeed: Double = 1.0
    @State private var cameraDistance: Double = 5.0
    @State private var effectIntensity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                MetalView(
                    projectionMode: $projectionMode,
                    renderMode: $renderMode,
                    showDebugInfo: $showDebugInfo,
                    particleCount: $particleCount,
                    rotationSpeed: $rotationSpeed,
                    cameraDistance: $cameraDistance
                )
                .ignoresSafeArea()

                if showDebugInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🚀 Metal Performance")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Projection: \(projectionMode == .perspective ? "Perspective" : "Orthographic")")
                            .font(.caption2)
                        Text("Render Mode: \(renderModeString)")
                            .font(.caption2)
                        Text("Particles: \(Int(particleCount))")
                            .font(.caption2)
                        Text("Camera Distance: \(String(format: "%.1f", cameraDistance))")
                            .font(.caption2)
                    }
                    .padding(8)
                    .background(.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                }
            }

            ScrollView {
                VStack(spacing: 20) {
                    // Render Mode Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Render Mode")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Picker("Render Mode", selection: $renderMode) {
                            Text("🎲 Cube").tag(MetalView.RenderMode.cube)
                            Text("🌐 Sphere").tag(MetalView.RenderMode.sphere)
                            Text("🍩 Torus").tag(MetalView.RenderMode.torus)
                            Text("✨ Particles").tag(MetalView.RenderMode.particles)
                            Text("🎨 Combined").tag(MetalView.RenderMode.combined)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Projection Mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Projection")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Picker("Projection", selection: $projectionMode) {
                            Text("Perspective").tag(MetalView.ProjectionMode.perspective)
                            Text("Orthographic").tag(MetalView.ProjectionMode.orthographic)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Interactive Controls
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Interactive Controls")
                            .font(.headline)
                            .foregroundColor(.primary)

                        // Particle Count
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Particles")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(particleCount))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $particleCount, in: 10...500, step: 10)
                                .accentColor(.blue)
                        }

                        // Rotation Speed
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Rotation Speed")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(String(format: "%.1fx", rotationSpeed))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $rotationSpeed, in: 0...3, step: 0.1)
                                .accentColor(.green)
                        }

                        // Camera Distance
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Camera Distance")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(String(format: "%.1f", cameraDistance))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $cameraDistance, in: 2...10, step: 0.5)
                                .accentColor(.purple)
                        }
                    }

                    // Debug Toggle
                    Toggle("Show Debug Info", isOn: $showDebugInfo)
                        .toggleStyle(SwitchToggleStyle())

                    // Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features")
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 4) {
                            Label("Advanced Phong lighting with multiple light sources", systemImage: "lightbulb.fill")
                                .font(.caption)
                            Label("Hologram and glow shader effects", systemImage: "sparkles")
                                .font(.caption)
                            Label("Real-time particle system", systemImage: "wind")
                                .font(.caption)
                            Label("Procedural noise and animations", systemImage: "waveform.path.ecg")
                                .font(.caption)
                            Label("HDR tone mapping and gamma correction", systemImage: "camera.filters")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var renderModeString: String {
        switch renderMode {
        case .cube: return "Cube"
        case .sphere: return "Sphere"
        case .torus: return "Torus"
        case .particles: return "Particles"
        case .combined: return "Combined"
        }
    }
}

#Preview {
    ContentView()
}