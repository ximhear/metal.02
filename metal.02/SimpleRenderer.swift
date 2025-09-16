import Metal
import MetalKit
import simd

struct SimpleVertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

struct SimpleUniforms {
    var modelMatrix: float4x4
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var time: Float
}

class SimpleRenderer: NSObject {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var depthState: MTLDepthStencilState?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer?

    var viewportSize: CGSize = CGSize(width: 1, height: 1)
    var rotation: Float = 0

    private var vertexCount: Int = 0
    private var indexCount: Int = 0

    init(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        self.commandQueue = queue
        super.init()

        buildPipeline()
        buildBuffers()
        buildDepthStencilState()
    }

    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create library")
            return
        }

        // Use simple shader for now to verify it works
        guard let vertexFunction = library.makeFunction(name: "simpleVertexShader"),
              let fragmentFunction = library.makeFunction(name: "simpleFragmentShader") else {
            print("Failed to load shader functions")
            return
        }

        let vertexDescriptor = MTLVertexDescriptor()
        // Position
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        // Color
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<SimpleVertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        // Don't use vertex descriptor for simple shader
        // pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        // pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.rasterSampleCount = 1

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("Pipeline state created successfully!")
        } catch {
            print("Error creating pipeline state: \(error)")
        }
    }

    private func buildBuffers() {
        // Create cube vertices
        let size: Float = 0.5
        let vertices: [SimpleVertex] = [
            // Front face (z = size) - Red
            SimpleVertex(position: SIMD3<Float>(-size, -size,  size), color: SIMD4<Float>(1, 0, 0, 1)),
            SimpleVertex(position: SIMD3<Float>( size, -size,  size), color: SIMD4<Float>(1, 0, 0, 1)),
            SimpleVertex(position: SIMD3<Float>( size,  size,  size), color: SIMD4<Float>(1, 0, 0, 1)),
            SimpleVertex(position: SIMD3<Float>(-size,  size,  size), color: SIMD4<Float>(1, 0, 0, 1)),

            // Back face (z = -size) - Green
            SimpleVertex(position: SIMD3<Float>(-size, -size, -size), color: SIMD4<Float>(0, 1, 0, 1)),
            SimpleVertex(position: SIMD3<Float>( size, -size, -size), color: SIMD4<Float>(0, 1, 0, 1)),
            SimpleVertex(position: SIMD3<Float>( size,  size, -size), color: SIMD4<Float>(0, 1, 0, 1)),
            SimpleVertex(position: SIMD3<Float>(-size,  size, -size), color: SIMD4<Float>(0, 1, 0, 1)),

            // Top face (y = size) - Blue
            SimpleVertex(position: SIMD3<Float>(-size,  size,  size), color: SIMD4<Float>(0, 0, 1, 1)),
            SimpleVertex(position: SIMD3<Float>( size,  size,  size), color: SIMD4<Float>(0, 0, 1, 1)),
            SimpleVertex(position: SIMD3<Float>( size,  size, -size), color: SIMD4<Float>(0, 0, 1, 1)),
            SimpleVertex(position: SIMD3<Float>(-size,  size, -size), color: SIMD4<Float>(0, 0, 1, 1)),

            // Bottom face (y = -size) - Yellow
            SimpleVertex(position: SIMD3<Float>(-size, -size,  size), color: SIMD4<Float>(1, 1, 0, 1)),
            SimpleVertex(position: SIMD3<Float>( size, -size,  size), color: SIMD4<Float>(1, 1, 0, 1)),
            SimpleVertex(position: SIMD3<Float>( size, -size, -size), color: SIMD4<Float>(1, 1, 0, 1)),
            SimpleVertex(position: SIMD3<Float>(-size, -size, -size), color: SIMD4<Float>(1, 1, 0, 1)),

            // Right face (x = size) - Magenta
            SimpleVertex(position: SIMD3<Float>( size, -size,  size), color: SIMD4<Float>(1, 0, 1, 1)),
            SimpleVertex(position: SIMD3<Float>( size, -size, -size), color: SIMD4<Float>(1, 0, 1, 1)),
            SimpleVertex(position: SIMD3<Float>( size,  size, -size), color: SIMD4<Float>(1, 0, 1, 1)),
            SimpleVertex(position: SIMD3<Float>( size,  size,  size), color: SIMD4<Float>(1, 0, 1, 1)),

            // Left face (x = -size) - Cyan
            SimpleVertex(position: SIMD3<Float>(-size, -size,  size), color: SIMD4<Float>(0, 1, 1, 1)),
            SimpleVertex(position: SIMD3<Float>(-size, -size, -size), color: SIMD4<Float>(0, 1, 1, 1)),
            SimpleVertex(position: SIMD3<Float>(-size,  size, -size), color: SIMD4<Float>(0, 1, 1, 1)),
            SimpleVertex(position: SIMD3<Float>(-size,  size,  size), color: SIMD4<Float>(0, 1, 1, 1))
        ]

        // Create index buffer - counter-clockwise winding
        let indices: [UInt16] = [
            // Front face
            0, 1, 2,    0, 2, 3,
            // Back face
            4, 5, 6,    4, 6, 7,
            // Top face
            8, 9, 10,   8, 10, 11,
            // Bottom face
            12, 13, 14, 12, 14, 15,
            // Right face
            16, 17, 18, 16, 18, 19,
            // Left face
            20, 21, 22, 20, 22, 23
        ]

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<SimpleVertex>.stride,
                                        options: [])

        indexBuffer = device.makeBuffer(bytes: indices,
                                       length: indices.count * MemoryLayout<UInt16>.size,
                                       options: [])

        uniformBuffer = device.makeBuffer(length: MemoryLayout<SimpleUniforms>.stride,
                                         options: [])

        vertexCount = vertices.count
        indexCount = indices.count

        print("Created vertex buffer with \(vertexCount) vertices and \(indexCount) indices")
    }

    private func buildDepthStencilState() {
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }

    private func updateUniforms() {
        rotation += 0.01

        // Simple rotation around Y axis
        let modelMatrix = float4x4(rotationY: rotation) * float4x4(rotationX: 0.3)

        // Camera at (0, 0, 3) looking at origin
        let viewMatrix = float4x4(translation: SIMD3<Float>(0, 0, -3))

        // Perspective projection
        let aspect = Float(viewportSize.width / viewportSize.height)
        let projectionMatrix = float4x4(perspectiveLeftHanded: Float.pi / 4,
                                       aspect,
                                       0.1,
                                       100.0)

        var uniforms = SimpleUniforms(modelMatrix: modelMatrix,
                                      viewMatrix: viewMatrix,
                                      projectionMatrix: projectionMatrix,
                                      time: Float(CACurrentMediaTime()))

        uniformBuffer?.contents().copyMemory(from: &uniforms,
                                            byteCount: MemoryLayout<SimpleUniforms>.stride)
    }
}

extension SimpleRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState,
              let drawable = view.currentDrawable else {
            print("Failed to get required rendering objects")
            return
        }

        updateUniforms()

        // Clear to dark blue
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.2, 1.0)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            print("Failed to create render encoder")
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        // renderEncoder.setDepthStencilState(depthState)
        // renderEncoder.setFrontFacing(.counterClockwise)
        // renderEncoder.setCullMode(.back)

        // Draw simple triangle without vertex buffer
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}