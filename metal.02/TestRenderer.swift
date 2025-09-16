import Metal
import MetalKit

class TestRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?

    init?(metalView: MTKView) {
        guard let device = metalView.device else { return nil }
        self.device = device
        self.commandQueue = device.makeCommandQueue()!

        super.init()

        // Create pipeline
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "testVertexShader"),
              let fragmentFunction = library.makeFunction(name: "testFragmentShader") else {
            print("Failed to load test shaders")
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            print("Test pipeline created successfully")
        } catch {
            print("Failed to create test pipeline: \(error)")
            return nil
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState else {
            return
        }

        // Set clear color to blue
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 1, alpha: 1)

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}