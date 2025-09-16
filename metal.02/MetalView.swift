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

        // Set up Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return mtkView
        }

        mtkView.device = device
        mtkView.delegate = context.coordinator  // Use coordinator as delegate

        // Configure view
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm
        // mtkView.depthStencilPixelFormat = .depth32Float  // Disable for debugging
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.5, alpha: 1.0)
        mtkView.sampleCount = 1

        // Initialize renderer in coordinator
        context.coordinator.setupRenderer(device: device)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update renderer properties if needed
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalView
        var testRenderer: TestRenderer?

        init(_ parent: MetalView) {
            self.parent = parent
            super.init()
        }

        func setupRenderer(device: MTLDevice) {
            // For now, keep it simple with basic test
            // We'll switch back to advanced renderer once basic rendering works
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Will be handled by renderer
        }

        func draw(in view: MTKView) {
            // Super simple inline rendering for testing
            guard let device = view.device,
                  let commandQueue = device.makeCommandQueue(),
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let descriptor = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable else {
                print("Failed to get Metal resources")
                return
            }

            // Clear to red to verify rendering is happening
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                print("Failed to create render encoder")
                return
            }

            // Just end encoding without drawing anything
            // This should at least show red screen
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}