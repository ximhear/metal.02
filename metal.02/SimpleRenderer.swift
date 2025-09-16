import Metal
import MetalKit

class SimpleRenderer: NSObject {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?

    init(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        self.commandQueue = queue
        super.init()

        buildPipeline()
    }

    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create library")
            return
        }

        guard let vertexFunction = library.makeFunction(name: "simpleVertexShader"),
              let fragmentFunction = library.makeFunction(name: "simpleFragmentShader") else {
            print("Failed to create shader functions")
            return
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.rasterSampleCount = 1  // No MSAA for now

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("Pipeline state created successfully!")
        } catch {
            print("Error creating pipeline state: \(error)")
        }
    }
}

extension SimpleRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Nothing to do here for simple triangle
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState,
              let drawable = view.currentDrawable else {
            print("Failed to get required rendering objects")
            return
        }

        // Clear to blue so we can see if rendering is happening
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.5, 1.0)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            print("Failed to create render encoder")
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}