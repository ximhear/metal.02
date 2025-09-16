import SwiftUI
import MetalKit
import simd

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
        mtkView.delegate = context.coordinator

        // Configure view
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 1.0)
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
        var depthState: MTLDepthStencilState?
        var commandQueue: MTLCommandQueue?
        var vertexBuffer: MTLBuffer?
        var indexBuffer: MTLBuffer?
        var uniformBuffer: MTLBuffer?

        var rotation: Float = 0
        var viewportSize: CGSize = CGSize(width: 1, height: 1)
        var vertexCount: Int = 0
        var indexCount: Int = 0

        init(_ parent: MetalView) {
            self.parent = parent
            super.init()
        }

        func setupRenderer(device: MTLDevice) {
            // Create command queue
            commandQueue = device.makeCommandQueue()

            // Create buffers
            createBuffers(device: device)

            // Create depth state
            createDepthState(device: device)

            // Create pipeline
            guard let library = device.makeDefaultLibrary() else {
                print("Failed to create library")
                return
            }

            // Use vertex buffer shader
            guard let vertexFunction = library.makeFunction(name: "simpleVertexBufferShader"),
                  let fragmentFunction = library.makeFunction(name: "simpleFragmentShader") else {
                print("Failed to load shader functions")
                return
            }

            // Create vertex descriptor
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
            vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                print("Pipeline state created successfully!")
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
        }

        func createBuffers(device: MTLDevice) {
            // Create cube vertices
            let size: Float = 0.5

            struct Vertex {
                var position: SIMD3<Float>
                var color: SIMD4<Float>
            }

            let vertices: [Vertex] = [
                // Front face (z = size) - Red
                Vertex(position: SIMD3<Float>(-size, -size,  size), color: SIMD4<Float>(1, 0, 0, 1)),
                Vertex(position: SIMD3<Float>( size, -size,  size), color: SIMD4<Float>(1, 0, 0, 1)),
                Vertex(position: SIMD3<Float>( size,  size,  size), color: SIMD4<Float>(1, 0, 0, 1)),
                Vertex(position: SIMD3<Float>(-size,  size,  size), color: SIMD4<Float>(1, 0, 0, 1)),

                // Back face (z = -size) - Green
                Vertex(position: SIMD3<Float>(-size, -size, -size), color: SIMD4<Float>(0, 1, 0, 1)),
                Vertex(position: SIMD3<Float>( size, -size, -size), color: SIMD4<Float>(0, 1, 0, 1)),
                Vertex(position: SIMD3<Float>( size,  size, -size), color: SIMD4<Float>(0, 1, 0, 1)),
                Vertex(position: SIMD3<Float>(-size,  size, -size), color: SIMD4<Float>(0, 1, 0, 1)),

                // Top face (y = size) - Blue
                Vertex(position: SIMD3<Float>(-size,  size,  size), color: SIMD4<Float>(0, 0, 1, 1)),
                Vertex(position: SIMD3<Float>( size,  size,  size), color: SIMD4<Float>(0, 0, 1, 1)),
                Vertex(position: SIMD3<Float>( size,  size, -size), color: SIMD4<Float>(0, 0, 1, 1)),
                Vertex(position: SIMD3<Float>(-size,  size, -size), color: SIMD4<Float>(0, 0, 1, 1)),

                // Bottom face (y = -size) - Yellow
                Vertex(position: SIMD3<Float>(-size, -size,  size), color: SIMD4<Float>(1, 1, 0, 1)),
                Vertex(position: SIMD3<Float>( size, -size,  size), color: SIMD4<Float>(1, 1, 0, 1)),
                Vertex(position: SIMD3<Float>( size, -size, -size), color: SIMD4<Float>(1, 1, 0, 1)),
                Vertex(position: SIMD3<Float>(-size, -size, -size), color: SIMD4<Float>(1, 1, 0, 1)),

                // Right face (x = size) - Magenta
                Vertex(position: SIMD3<Float>( size, -size,  size), color: SIMD4<Float>(1, 0, 1, 1)),
                Vertex(position: SIMD3<Float>( size, -size, -size), color: SIMD4<Float>(1, 0, 1, 1)),
                Vertex(position: SIMD3<Float>( size,  size, -size), color: SIMD4<Float>(1, 0, 1, 1)),
                Vertex(position: SIMD3<Float>( size,  size,  size), color: SIMD4<Float>(1, 0, 1, 1)),

                // Left face (x = -size) - Cyan
                Vertex(position: SIMD3<Float>(-size, -size,  size), color: SIMD4<Float>(0, 1, 1, 1)),
                Vertex(position: SIMD3<Float>(-size, -size, -size), color: SIMD4<Float>(0, 1, 1, 1)),
                Vertex(position: SIMD3<Float>(-size,  size, -size), color: SIMD4<Float>(0, 1, 1, 1)),
                Vertex(position: SIMD3<Float>(-size,  size,  size), color: SIMD4<Float>(0, 1, 1, 1))
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
                                            length: vertices.count * MemoryLayout<Vertex>.stride,
                                            options: [])

            indexBuffer = device.makeBuffer(bytes: indices,
                                           length: indices.count * MemoryLayout<UInt16>.size,
                                           options: [])

            // Uniforms struct size: 3 matrices (64 bytes each) + 1 float (4 bytes) = 196 bytes
            // But Metal requires 16-byte alignment, so time field needs padding
            let uniformsSize = MemoryLayout<float4x4>.size * 3 + 16  // 192 + 16 = 208 for alignment
            uniformBuffer = device.makeBuffer(length: uniformsSize, options: [])

            vertexCount = vertices.count
            indexCount = indices.count

            print("Created buffers: \(vertexCount) vertices, \(indexCount) indices")
        }

        func createDepthState(device: MTLDevice) {
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.depthCompareFunction = .less
            depthDescriptor.isDepthWriteEnabled = true
            depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        }

        func updateUniforms() {
            rotation += 0.01

            // Create transformation matrices
            let modelMatrix = float4x4(rotationY: rotation) * float4x4(rotationX: 0.3)
            let viewMatrix = float4x4(translation: SIMD3<Float>(0, 0, -3))
            let aspect = Float(viewportSize.width / viewportSize.height)
            let projectionMatrix = float4x4(perspectiveLeftHanded: Float.pi / 4,
                                           aspect,
                                           0.1,
                                           100.0)

            // Create uniforms struct matching shader layout
            struct Uniforms {
                var modelMatrix: float4x4
                var viewMatrix: float4x4
                var projectionMatrix: float4x4
                var time: Float
                var padding: SIMD3<Float> = SIMD3<Float>(0, 0, 0)  // Padding for 16-byte alignment
            }

            var uniforms = Uniforms(
                modelMatrix: modelMatrix,
                viewMatrix: viewMatrix,
                projectionMatrix: projectionMatrix,
                time: Float(CACurrentMediaTime())
            )

            uniformBuffer?.contents().copyMemory(from: &uniforms,
                                                byteCount: MemoryLayout<Uniforms>.size)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            viewportSize = size
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

            updateUniforms()

            // Clear to dark blue
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 1.0)

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                print("Failed to create render encoder")
                return
            }

            // Set pipeline and buffers
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setDepthStencilState(depthState)
            renderEncoder.setFrontFacing(.counterClockwise)
            renderEncoder.setCullMode(.back)

            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)

            // Draw indexed cube
            if let indexBuffer = indexBuffer {
                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                   indexCount: indexCount,
                                                   indexType: .uint16,
                                                   indexBuffer: indexBuffer,
                                                   indexBufferOffset: 0)
            }

            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}