import Metal
import MetalKit
import simd

struct Vertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

struct Uniforms {
    var modelMatrix: float4x4
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var time: Float
}

class Renderer: NSObject {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var depthState: MTLDepthStencilState?
    var vertexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer?
    
    var viewportSize: CGSize = CGSize(width: 1, height: 1)
    var projectionMode: MetalView.ProjectionMode = .perspective
    var rotation: Float = 0
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        
        buildPipeline()
        buildBuffers()
        buildDepthStencilState()
    }
    
    private func buildPipeline() {
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
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
        } catch {
            print("Error creating pipeline state: \(error)")
        }
    }
    
    private func buildBuffers() {
        let radius : Float = 1.0
        let vertices: [Vertex] = [
            Vertex(position: SIMD3<Float>( radius * cos(.pi / 2.0),
                                           radius * sin(.pi / 2.0), 0.0),
                   color: SIMD4<Float>(1.0, 0.0, 0.0, 1.0)),
            Vertex(position: SIMD3<Float>( radius * cos(.pi / 2.0 + .pi * 2.0 / 3.0),
                                           radius * sin(.pi / 2.0 + .pi * 2.0 / 3.0), 0.0),
                   color: SIMD4<Float>(0.0, 1.0, 0.0, 1.0)),
            Vertex(position: SIMD3<Float>( radius * cos(.pi / 2.0 + .pi * 4.0 / 3.0),
                                           radius * sin(.pi / 2.0 + .pi * 4.0 / 3.0), 0.0),
                   color: SIMD4<Float>(0.0, 0.0, 1.0, 1.0))
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<Vertex>.stride,
                                        options: [])
        
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                         options: [])
    }
    
    private func buildDepthStencilState() {
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }
    
    private func updateUniforms() {
//        rotation += 0.01
        rotation = Float(CACurrentMediaTime())
        
        let modelMatrix = float4x4(rotationY: 0) * float4x4(rotationX: 0.0) * float4x4(rotationZ: rotation)
        
        let viewMatrix = float4x4(translation: SIMD3<Float>(0, 0, 4))
        
        let aspect = Float(viewportSize.width / viewportSize.height)
        let projectionMatrix: float4x4
        
        switch projectionMode {
        case .orthographic:
            let orthoHeight: Float = aspect > 1 ? 2.0 : 2.0 / aspect
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
        var uniforms = Uniforms(modelMatrix: modelMatrix,
                               viewMatrix: viewMatrix,
                               projectionMatrix: projectionMatrix,
                                time: Float(CACurrentMediaTime()))
        
        uniformBuffer?.contents().copyMemory(from: &uniforms,
                                            byteCount: MemoryLayout<Uniforms>.stride)
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState,
              let drawable = view.currentDrawable else {
            return
        }
        
        updateUniforms()
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(.back)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

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
}

