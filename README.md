# Metal.01 - SwiftUI Metal Renderer

A simple iOS application demonstrating Metal rendering with SwiftUI, featuring a rotating triangle with support for both orthographic and perspective projections.

## Features

- **SwiftUI Integration**: Metal view wrapped as a UIViewRepresentable for seamless SwiftUI integration
- **Dual Projection Modes**: Toggle between perspective and orthographic projections
- **Left-Handed Coordinate System**: Implements left-handed coordinate system for Metal rendering
- **Animated Triangle**: Rotating triangle with RGB vertex colors
- **Real-time Rendering**: 60 FPS continuous rendering with time-based animations

## Architecture

### Components

- **MetalView.swift**: SwiftUI view wrapper for MTKView
- **Renderer.swift**: Core rendering logic, matrix transformations, and uniform buffer management
- **Shaders.metal**: Vertex and fragment shaders with time-based animations
- **ContentView.swift**: Main UI with projection mode picker

### Key Features

- Vertex descriptor configuration for proper attribute binding
- Depth buffer support with depth testing
- Back-face culling with counter-clockwise winding
- Time-based vertex position and color animations in shaders

## Requirements

- iOS 14.0+
- Xcode 12.0+
- Device with Metal support

## Usage

Run the app and use the segmented control at the bottom to switch between Perspective and Orthographic projection modes. The triangle will rotate continuously with animated colors and vertices.