import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    @Binding var projectionMode: ProjectionMode
    @Binding var renderMode: RenderMode
    @Binding var showDebugInfo: Bool
    @Binding var particleCount: Double
    @Binding var rotationSpeed: Double
    @Binding var cameraDistance: Double

    enum ProjectionMode {
        case orthographic
        case perspective
    }

    enum RenderMode {
        case cube
        case sphere
        case torus
        case particles
        case combined
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
            context.coordinator.renderer = Renderer(device: device)
        }

        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0)

        // Enable multi-sampling for smoother edges
        mtkView.sampleCount = 4

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }

        renderer.projectionMode = projectionMode
        renderer.isDebugMode = showDebugInfo

        // Update render mode
        switch renderMode {
        case .cube:
            renderer.switchToCube()
        case .sphere:
            renderer.switchToSphere()
        case .torus:
            renderer.switchToTorus()
        case .particles:
            renderer.switchToParticles()
        case .combined:
            renderer.switchToCombined()
        }

        // Update dynamic parameters
        context.coordinator.updateDynamicParameters(
            particleCount: Int(particleCount),
            rotationSpeed: Float(rotationSpeed),
            cameraDistance: Float(cameraDistance)
        )
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalView
        var renderer: Renderer?

        init(_ parent: MetalView) {
            self.parent = parent
        }

        func updateDynamicParameters(particleCount: Int, rotationSpeed: Float, cameraDistance: Float) {
            // These would be passed to the renderer if we exposed them as properties
            // For now they're handled internally in the renderer
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }

        func draw(in view: MTKView) {
            renderer?.draw(in: view)
        }
    }
}