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
        var pipelineState: MTLRenderPipelineState?
        var commandQueue: MTLCommandQueue?

        init(_ parent: MetalView) {
            self.parent = parent
            super.init()
        }

        func setupRenderer(device: MTLDevice) {
            // Create command queue
            commandQueue = device.makeCommandQueue()

            // Create pipeline
            guard let library = device.makeDefaultLibrary() else {
                print("Failed to create library")
                return
            }

            // Try to load simple shader
            guard let vertexFunction = library.makeFunction(name: "simpleVertexShader"),
                  let fragmentFunction = library.makeFunction(name: "simpleFragmentShader") else {
                print("Failed to load shader functions")
                return
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                print("Pipeline state created successfully!")
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Will be handled by renderer
        }

        func draw(in view: MTKView) {
            guard let commandQueue = commandQueue,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let descriptor = view.currentRenderPassDescriptor,
                  let pipelineState = pipelineState,
                  let drawable = view.currentDrawable else {
                print("Failed to get Metal resources")
                return
            }

            // Clear to dark blue
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 1.0)

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                print("Failed to create render encoder")
                return
            }

            // Set pipeline and draw triangle
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}