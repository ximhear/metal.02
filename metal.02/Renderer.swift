import Metal
import MetalKit
import simd

struct Vertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
    var normal: SIMD3<Float>
    var texCoord: SIMD2<Float>
}

struct Uniforms {
    var modelMatrix: float4x4
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var time: Float
    var cameraPosition: SIMD3<Float>
    var particleSize: Float
}

enum RenderMode {
    case cube
    case sphere
    case torus
    case particles
    case combined
}

class Renderer: NSObject {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var glowPipelineState: MTLRenderPipelineState?
    var hologramPipelineState: MTLRenderPipelineState?
    var particlePipelineState: MTLRenderPipelineState?
    var depthState: MTLDepthStencilState?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer?
    var particleBuffer: MTLBuffer?
    var textureLoader: MTKTextureLoader

    var viewportSize: CGSize = CGSize(width: 1, height: 1)
    var projectionMode: MetalView.ProjectionMode = .perspective
    var rotation: Float = 0
    var renderMode: RenderMode = .combined

    private var currentVertexCount: Int = 0
    private var currentIndexCount: Int = 0
    private var particleCount: Int = 100

    private var cameraRotation: Float = 0
    private var cameraDistance: Float = 4
    private var cameraHeight: Float = 1

    private var frameCount = 0
    private var lastFPSUpdateTime: CFTimeInterval = 0
    private var currentFPS: Double = 0

    var isDebugMode: Bool = false

    init(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = queue
        self.textureLoader = MTKTextureLoader(device: device)
        super.init()

        buildPipelines()
        buildBuffers()
        createCubeGeometry()
        createParticleSystem()
        buildDepthStencilState()

        // Check if pipelines were created successfully
        if pipelineState == nil {
            print("ERROR: Main pipeline state is nil")
        }
    }

    private func buildPipelines() {
        let library = device.makeDefaultLibrary()

        let vertexDescriptor = createVertexDescriptor()

        // Main pipeline with advanced lighting
        pipelineState = createPipelineState(
            vertexFunction: "vertexShader",
            fragmentFunction: "fragmentShader",
            vertexDescriptor: vertexDescriptor,
            library: library
        )

        // Glow effect pipeline
        glowPipelineState = createPipelineState(
            vertexFunction: "vertexShader",
            fragmentFunction: "glowFragmentShader",
            vertexDescriptor: vertexDescriptor,
            library: library
        )

        // Hologram pipeline
        hologramPipelineState = createPipelineState(
            vertexFunction: "vertexShader",
            fragmentFunction: "hologramFragmentShader",
            vertexDescriptor: vertexDescriptor,
            library: library,
            enableBlending: true
        )

        // Particle pipeline
        particlePipelineState = createPipelineState(
            vertexFunction: "particleVertexShader",
            fragmentFunction: "glowFragmentShader",
            vertexDescriptor: vertexDescriptor,
            library: library,
            enableBlending: true
        )
    }

    private func createVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()

        // Position
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        // Color
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0

        // Normal
        vertexDescriptor.attributes[2].format = .float3
        vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[2].bufferIndex = 0

        // Texture coordinates
        vertexDescriptor.attributes[3].format = .float2
        vertexDescriptor.attributes[3].offset = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride + MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[3].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        return vertexDescriptor
    }

    private func createPipelineState(
        vertexFunction: String,
        fragmentFunction: String,
        vertexDescriptor: MTLVertexDescriptor,
        library: MTLLibrary?,
        enableBlending: Bool = false
    ) -> MTLRenderPipelineState? {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: vertexFunction)
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: fragmentFunction)
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.rasterSampleCount = 4  // Match MTKView's sample count

        if enableBlending {
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error creating pipeline state: \(error)")
            return nil
        }
    }

    private func buildBuffers() {
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                         options: [])
    }

    private func createCubeGeometry() {
        let size: Float = 1.0

        // Create vertices for a cube with normals
        let vertices: [Vertex] = [
            // Front face (z = size)
            Vertex(position: SIMD3<Float>(-size, -size,  size), color: SIMD4<Float>(1, 0, 0, 1), normal: SIMD3<Float>(0, 0, 1), texCoord: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD3<Float>( size, -size,  size), color: SIMD4<Float>(0, 1, 0, 1), normal: SIMD3<Float>(0, 0, 1), texCoord: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD3<Float>( size,  size,  size), color: SIMD4<Float>(0, 0, 1, 1), normal: SIMD3<Float>(0, 0, 1), texCoord: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD3<Float>(-size,  size,  size), color: SIMD4<Float>(1, 1, 0, 1), normal: SIMD3<Float>(0, 0, 1), texCoord: SIMD2<Float>(0, 1)),

            // Back face (z = -size)
            Vertex(position: SIMD3<Float>(-size, -size, -size), color: SIMD4<Float>(1, 0, 1, 1), normal: SIMD3<Float>(0, 0, -1), texCoord: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD3<Float>( size, -size, -size), color: SIMD4<Float>(0, 1, 1, 1), normal: SIMD3<Float>(0, 0, -1), texCoord: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD3<Float>( size,  size, -size), color: SIMD4<Float>(1, 1, 1, 1), normal: SIMD3<Float>(0, 0, -1), texCoord: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD3<Float>(-size,  size, -size), color: SIMD4<Float>(0.5, 0.5, 0.5, 1), normal: SIMD3<Float>(0, 0, -1), texCoord: SIMD2<Float>(1, 1)),

            // Top face (y = size)
            Vertex(position: SIMD3<Float>(-size,  size,  size), color: SIMD4<Float>(0.8, 0.2, 0.2, 1), normal: SIMD3<Float>(0, 1, 0), texCoord: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD3<Float>( size,  size,  size), color: SIMD4<Float>(0.2, 0.8, 0.2, 1), normal: SIMD3<Float>(0, 1, 0), texCoord: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD3<Float>( size,  size, -size), color: SIMD4<Float>(0.2, 0.2, 0.8, 1), normal: SIMD3<Float>(0, 1, 0), texCoord: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD3<Float>(-size,  size, -size), color: SIMD4<Float>(0.8, 0.8, 0.2, 1), normal: SIMD3<Float>(0, 1, 0), texCoord: SIMD2<Float>(0, 1)),

            // Bottom face (y = -size)
            Vertex(position: SIMD3<Float>(-size, -size,  size), color: SIMD4<Float>(0.8, 0.2, 0.8, 1), normal: SIMD3<Float>(0, -1, 0), texCoord: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD3<Float>( size, -size,  size), color: SIMD4<Float>(0.2, 0.8, 0.8, 1), normal: SIMD3<Float>(0, -1, 0), texCoord: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD3<Float>( size, -size, -size), color: SIMD4<Float>(0.5, 0.5, 0.2, 1), normal: SIMD3<Float>(0, -1, 0), texCoord: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD3<Float>(-size, -size, -size), color: SIMD4<Float>(0.2, 0.5, 0.5, 1), normal: SIMD3<Float>(0, -1, 0), texCoord: SIMD2<Float>(0, 0)),

            // Right face (x = size)
            Vertex(position: SIMD3<Float>( size, -size,  size), color: SIMD4<Float>(0.9, 0.3, 0.3, 1), normal: SIMD3<Float>(1, 0, 0), texCoord: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD3<Float>( size, -size, -size), color: SIMD4<Float>(0.3, 0.9, 0.3, 1), normal: SIMD3<Float>(1, 0, 0), texCoord: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD3<Float>( size,  size, -size), color: SIMD4<Float>(0.3, 0.3, 0.9, 1), normal: SIMD3<Float>(1, 0, 0), texCoord: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD3<Float>( size,  size,  size), color: SIMD4<Float>(0.9, 0.9, 0.3, 1), normal: SIMD3<Float>(1, 0, 0), texCoord: SIMD2<Float>(0, 1)),

            // Left face (x = -size)
            Vertex(position: SIMD3<Float>(-size, -size,  size), color: SIMD4<Float>(0.9, 0.3, 0.9, 1), normal: SIMD3<Float>(-1, 0, 0), texCoord: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD3<Float>(-size, -size, -size), color: SIMD4<Float>(0.3, 0.9, 0.9, 1), normal: SIMD3<Float>(-1, 0, 0), texCoord: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD3<Float>(-size,  size, -size), color: SIMD4<Float>(0.6, 0.6, 0.3, 1), normal: SIMD3<Float>(-1, 0, 0), texCoord: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD3<Float>(-size,  size,  size), color: SIMD4<Float>(0.3, 0.6, 0.6, 1), normal: SIMD3<Float>(-1, 0, 0), texCoord: SIMD2<Float>(1, 1))
        ]

        // Create index buffer for cube faces (counter-clockwise winding)
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

        currentVertexCount = vertices.count
        currentIndexCount = indices.count
    }

    private func createSphereGeometry(latitudeBands: Int = 30, longitudeBands: Int = 30) {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []

        let radius: Float = 1.0

        for latNumber in 0...latitudeBands {
            let theta = Float(latNumber) * .pi / Float(latitudeBands)
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            for longNumber in 0...longitudeBands {
                let phi = Float(longNumber) * 2.0 * .pi / Float(longitudeBands)
                let sinPhi = sin(phi)
                let cosPhi = cos(phi)

                let x = cosPhi * sinTheta
                let y = cosTheta
                let z = sinPhi * sinTheta

                let position = SIMD3<Float>(x * radius, y * radius, z * radius)
                let normal = SIMD3<Float>(x, y, z)
                let texCoord = SIMD2<Float>(Float(longNumber) / Float(longitudeBands),
                                           Float(latNumber) / Float(latitudeBands))

                let color = SIMD4<Float>(
                    abs(x),
                    abs(y),
                    abs(z),
                    1.0
                )

                vertices.append(Vertex(position: position, color: color, normal: normal, texCoord: texCoord))
            }
        }

        for latNumber in 0..<latitudeBands {
            for longNumber in 0..<longitudeBands {
                let first = UInt16((latNumber * (longitudeBands + 1)) + longNumber)
                let second = UInt16(first + UInt16(longitudeBands) + 1)

                indices.append(first)
                indices.append(second)
                indices.append(first + 1)

                indices.append(second)
                indices.append(second + 1)
                indices.append(first + 1)
            }
        }

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<Vertex>.stride,
                                        options: [])

        indexBuffer = device.makeBuffer(bytes: indices,
                                       length: indices.count * MemoryLayout<UInt16>.size,
                                       options: [])

        currentVertexCount = vertices.count
        currentIndexCount = indices.count
    }

    private func createTorusGeometry(majorRadius: Float = 1.0, minorRadius: Float = 0.4, majorSegments: Int = 30, minorSegments: Int = 20) {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []

        for i in 0...majorSegments {
            let theta = 2.0 * .pi * Float(i) / Float(majorSegments)
            let cosTheta = cos(theta)
            let sinTheta = sin(theta)

            for j in 0...minorSegments {
                let phi = 2.0 * .pi * Float(j) / Float(minorSegments)
                let cosPhi = cos(phi)
                let sinPhi = sin(phi)

                let x = (majorRadius + minorRadius * cosPhi) * cosTheta
                let y = minorRadius * sinPhi
                let z = (majorRadius + minorRadius * cosPhi) * sinTheta

                let position = SIMD3<Float>(x, y, z)

                let nx = cosPhi * cosTheta
                let ny = sinPhi
                let nz = cosPhi * sinTheta
                let normal = SIMD3<Float>(nx, ny, nz)

                let texCoord = SIMD2<Float>(Float(i) / Float(majorSegments),
                                           Float(j) / Float(minorSegments))

                let color = SIMD4<Float>(
                    (sin(theta) + 1.0) * 0.5,
                    (cos(phi) + 1.0) * 0.5,
                    (sin(phi) + 1.0) * 0.5,
                    1.0
                )

                vertices.append(Vertex(position: position, color: color, normal: normal, texCoord: texCoord))
            }
        }

        for i in 0..<majorSegments {
            for j in 0..<minorSegments {
                let current = UInt16(i * (minorSegments + 1) + j)
                let next = UInt16(current + UInt16(minorSegments) + 1)

                indices.append(current)
                indices.append(next)
                indices.append(current + 1)

                indices.append(next)
                indices.append(next + 1)
                indices.append(current + 1)
            }
        }

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<Vertex>.stride,
                                        options: [])

        indexBuffer = device.makeBuffer(bytes: indices,
                                       length: indices.count * MemoryLayout<UInt16>.size,
                                       options: [])

        currentVertexCount = vertices.count
        currentIndexCount = indices.count
    }

    private func createParticleSystem() {
        var particles: [Vertex] = []

        // Create simple quad for each particle
        let particleVertices: [SIMD3<Float>] = [
            SIMD3<Float>(-0.05, -0.05, 0),
            SIMD3<Float>( 0.05, -0.05, 0),
            SIMD3<Float>( 0.05,  0.05, 0),
            SIMD3<Float>(-0.05, -0.05, 0),
            SIMD3<Float>( 0.05,  0.05, 0),
            SIMD3<Float>(-0.05,  0.05, 0)
        ]

        for position in particleVertices {
            particles.append(Vertex(
                position: position,
                color: SIMD4<Float>(1, 1, 1, 1),
                normal: SIMD3<Float>(0, 0, 1),
                texCoord: SIMD2<Float>(0, 0)
            ))
        }

        particleBuffer = device.makeBuffer(bytes: particles,
                                          length: particles.count * MemoryLayout<Vertex>.stride,
                                          options: [])
    }

    private func buildDepthStencilState() {
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }

    private func updateUniforms() {
        rotation = Float(CACurrentMediaTime())
        cameraRotation += 0.01

        // Animated camera position
        let camX = sin(cameraRotation) * cameraDistance
        let camZ = cos(cameraRotation) * cameraDistance
        let cameraPosition = SIMD3<Float>(camX, cameraHeight + sin(rotation * 0.5), camZ)

        // Simpler model matrix for debugging
        let modelMatrix = float4x4(rotationY: rotation) * float4x4(scale: 0.5)

        // Simple translation view matrix for debugging
        let viewMatrix = float4x4(translation: SIMD3<Float>(0, 0, -4))

        let aspect = Float(viewportSize.width / viewportSize.height)
        let projectionMatrix: float4x4

        switch projectionMode {
        case .orthographic:
            let orthoHeight: Float = 4.0
            let orthoWidth: Float = orthoHeight * aspect
            projectionMatrix = float4x4(orthographicLeftHanded: -orthoWidth/2, orthoWidth/2,
                                       -orthoHeight/2, orthoHeight/2,
                                       0.1, 100.0)
        case .perspective:
            projectionMatrix = float4x4(perspectiveLeftHanded: Float.pi / 4,
                                       aspect,
                                       0.1,
                                       100.0)
        }

        var uniforms = Uniforms(
            modelMatrix: modelMatrix,
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            time: Float(CACurrentMediaTime()),
            cameraPosition: cameraPosition,
            particleSize: 0.1
        )

        uniformBuffer?.contents().copyMemory(from: &uniforms,
                                            byteCount: MemoryLayout<Uniforms>.stride)
    }

    // Public methods to change render mode
    func switchToCube() {
        renderMode = .cube
        createCubeGeometry()
    }

    func switchToSphere() {
        renderMode = .sphere
        createSphereGeometry()
    }

    func switchToTorus() {
        renderMode = .torus
        createTorusGeometry()
    }

    func switchToParticles() {
        renderMode = .particles
    }

    func switchToCombined() {
        renderMode = .combined
        createCubeGeometry()
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }

        updateUniforms()
        updateFPS()

        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.05, 0.05, 0.15, 1.0)

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!

        if isDebugMode {
            renderEncoder.label = "Main Render Pass"
        }

        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(.none)  // Disable culling temporarily to debug

        // Render main geometry
        if renderMode != .particles {
            // Only render main pipeline for debugging
            renderEncoder.setRenderPipelineState(pipelineState!)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                               indexCount: currentIndexCount,
                                               indexType: .uint16,
                                               indexBuffer: indexBuffer!,
                                               indexBufferOffset: 0)
        }

        // Render particles
        if renderMode == .particles || renderMode == .combined {
            renderEncoder.setRenderPipelineState(particlePipelineState!)
            renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)

            // Draw multiple particle instances
            renderEncoder.drawPrimitives(type: .triangle,
                                        vertexStart: 0,
                                        vertexCount: 6,
                                        instanceCount: particleCount)
        }

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func updateFPS() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()

        if currentTime - lastFPSUpdateTime >= 1.0 {
            currentFPS = Double(frameCount) / (currentTime - lastFPSUpdateTime)
            frameCount = 0
            lastFPSUpdateTime = currentTime

            if isDebugMode {
                print("FPS: \(String(format: "%.1f", currentFPS))")
            }
        }
    }

    var fps: Double {
        return currentFPS
    }
}

// MARK: - Matrix Extensions
extension float4x4 {
    init(rotationX angle: Float) {
        self = float4x4(
            [1, 0, 0, 0],
            [0, cos(angle), sin(angle), 0],
            [0, -sin(angle), cos(angle), 0],
            [0, 0, 0, 1]
        )
    }

    init(rotationY angle: Float) {
        self = float4x4(
            [cos(angle), 0, -sin(angle), 0],
            [0, 1, 0, 0],
            [sin(angle), 0, cos(angle), 0],
            [0, 0, 0, 1]
        )
    }

    init(rotationZ angle: Float) {
        self = float4x4(
            [cos(angle), sin(angle), 0, 0],
            [-sin(angle), cos(angle), 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        )
    }

    init(translation: SIMD3<Float>) {
        self = float4x4(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [translation.x, translation.y, translation.z, 1]
        )
    }

    init(lookAt eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) {
        let z = normalize(eye - target)
        let x = normalize(cross(up, z))
        let y = cross(z, x)

        self = float4x4(
            [x.x, y.x, z.x, 0],
            [x.y, y.y, z.y, 0],
            [x.z, y.z, z.z, 0],
            [-dot(x, eye), -dot(y, eye), -dot(z, eye), 1]
        )
    }

    init(perspectiveLeftHanded fov: Float, _ aspect: Float, _ near: Float, _ far: Float) {
        let yScale = 1 / tan(fov * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = far / zRange
        let wzScale = -(far * near) / zRange

        self = float4x4(
            [xScale, 0, 0, 0],
            [0, yScale, 0, 0],
            [0, 0, zScale, 1],
            [0, 0, wzScale, 0]
        )
    }

    init(orthographicLeftHanded left: Float, _ right: Float,
         _ bottom: Float, _ top: Float,
         _ near: Float, _ far: Float) {
        let ral = right - left
        let tab = top - bottom
        let fan = far - near

        self = float4x4(
            [2.0 / ral, 0, 0, 0],
            [0, 2.0 / tab, 0, 0],
            [0, 0, 1.0 / fan, 0],
            [-(right + left) / ral, -(top + bottom) / tab, -near / fan, 1]
        )
    }

    init(scale: Float) {
        self = float4x4(
            [scale, 0, 0, 0],
            [0, scale, 0, 0],
            [0, 0, scale, 0],
            [0, 0, 0, 1]
        )
    }

    static func *(left: float4x4, right: float4x4) -> float4x4 {
        return simd_mul(left, right)
    }
}

// Helper functions
func normalize(_ v: SIMD3<Float>) -> SIMD3<Float> {
    let len = length(v)
    return len > 0 ? v / len : SIMD3<Float>(0, 0, 0)
}

func cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    return SIMD3<Float>(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
}

func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
    return a.x * b.x + a.y * b.y + a.z * b.z
}

func length(_ v: SIMD3<Float>) -> Float {
    return sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
}