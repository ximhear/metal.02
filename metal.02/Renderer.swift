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
    var textureLoader: MTKTextureLoader
    
    var viewportSize: CGSize = CGSize(width: 1, height: 1)
    var projectionMode: MetalView.ProjectionMode = .perspective
    var rotation: Float = 0
    
    // 현재 렌더링할 vertex 개수
    private var currentVertexCount: Int = 0
    
    // 성능 모니터링
    private var frameCount = 0
    private var lastFPSUpdateTime: CFTimeInterval = 0
    private var currentFPS: Double = 0
    
    // 디버그 모드
    var isDebugMode: Bool = false
    
    init(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = queue
        self.textureLoader = MTKTextureLoader(device: device)
        super.init()
        
        buildPipeline()
        buildBuffers()
//        useTriangle()
//        useQuad()
        useCircle(segments: 128)
        guard let _ = vertexBuffer else {
            fatalError("Failed to create vertex buffer")
        }
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
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                         options: [])
    }
    
    private func createTriangleBuffer() -> MTLBuffer? {
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
        
        return device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<Vertex>.stride,
                                        options: [])
    }
    
    // 추가 도형 생성 함수들
    private func createQuadBuffer() -> MTLBuffer? {
        let vertices: [Vertex] = [
            // 첫 번째 삼각형
            Vertex(position: SIMD3<Float>(-1.0, -1.0, 0.0), color: SIMD4<Float>(1.0, 0.0, 0.0, 1.0)),
            Vertex(position: SIMD3<Float>( 1.0, -1.0, 0.0), color: SIMD4<Float>(0.0, 1.0, 0.0, 1.0)),
            Vertex(position: SIMD3<Float>( 1.0,  1.0, 0.0), color: SIMD4<Float>(0.0, 0.0, 1.0, 1.0)),
            
            // 두 번째 삼각형
            Vertex(position: SIMD3<Float>(-1.0, -1.0, 0.0), color: SIMD4<Float>(1.0, 0.0, 0.0, 1.0)),
            Vertex(position: SIMD3<Float>( 1.0,  1.0, 0.0), color: SIMD4<Float>(0.0, 0.0, 1.0, 1.0)),
            Vertex(position: SIMD3<Float>(-1.0,  1.0, 0.0), color: SIMD4<Float>(1.0, 1.0, 0.0, 1.0))
        ]
        
        return device.makeBuffer(bytes: vertices,
                                length: vertices.count * MemoryLayout<Vertex>.stride,
                                options: [])
    }
    
    private func createCircleBuffer(segments: Int = 32) -> MTLBuffer? {
        var vertices: [Vertex] = []
        
        let centerColor = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
        
        // 삼각형 팬으로 원형 생성 (각 삼각형마다 3개의 vertex)
        for i in 0..<segments {
            let angle1 = Float(i) * 2.0 * .pi / Float(segments)
            let angle2 = Float(i + 1) * 2.0 * .pi / Float(segments)
            
            let x1 = cos(angle1)
            let y1 = sin(angle1)
            let x2 = cos(angle2)
            let y2 = sin(angle2)
            
            let color1 = SIMD4<Float>(cos(angle1) * 0.5 + 0.5, 
                                     sin(angle1) * 0.5 + 0.5, 
                                     0.5, 1.0)
            let color2 = SIMD4<Float>(cos(angle2) * 0.5 + 0.5, 
                                     sin(angle2) * 0.5 + 0.5, 
                                     0.5, 1.0)
            
            // 각 삼각형: center -> point1 -> point2
            vertices.append(Vertex(position: SIMD3<Float>(0, 0, 0), color: centerColor))
            vertices.append(Vertex(position: SIMD3<Float>(x1, y1, 0), color: color1))
            vertices.append(Vertex(position: SIMD3<Float>(x2, y2, 0), color: color2))
        }
        
        return device.makeBuffer(bytes: vertices,
                                length: vertices.count * MemoryLayout<Vertex>.stride,
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
        updateFPS()
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        if isDebugMode {
            renderEncoder.label = "Main Render Pass"
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(.back)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)

        // 저장된 vertex 개수 사용 (더 효율적)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: currentVertexCount)
        
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
    
    // 공개 FPS getter
    var fps: Double {
        return currentFPS
    }
    
    // MARK: - 도형 변경 메서드들
    
    /// 삼각형으로 변경
    func useTriangle() {
        vertexBuffer = createTriangleBuffer()
        currentVertexCount = 3
    }
    
    /// 사각형으로 변경
    func useQuad() {
        vertexBuffer = createQuadBuffer()
        currentVertexCount = 6
    }
    
    /// 원형으로 변경
    func useCircle(segments: Int = 32) {
        vertexBuffer = createCircleBuffer(segments: segments)
        // 원형은 center vertex (1개) + edge vertices (segments + 1개) = segments + 2개
        // 하지만 실제로는 삼각형들로 그려지므로 segments * 3개
        currentVertexCount = segments * 3
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
    
    init(scaleX: Float, scaleY: Float, scaleZ: Float) {
        self = float4x4(
            [scaleX, 0, 0, 0],
            [0, scaleY, 0, 0],
            [0, 0, scaleZ, 0],
            [0, 0, 0, 1]
        )
    }
    
    // 행렬 곱셈 연산자
    static func *(left: float4x4, right: float4x4) -> float4x4 {
        return simd_mul(left, right)
    }
}

// MARK: - Math Utilities
extension Float {
    /// 도(degree)를 라디안으로 변환
    var radians: Float {
        return self * .pi / 180.0
    }
    
    /// 라디안을 도(degree)로 변환
    var degrees: Float {
        return self * 180.0 / .pi
    }
    
    /// fract 함수 구현 (소수 부분만 반환)
    func fract() -> Float {
        return self - floor(self)
    }
    
    /// 값을 지정된 범위로 클램프
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
    
    /// 선형 보간
    func lerp(to target: Float, t: Float) -> Float {
        return self + (target - self) * t
    }
}

extension SIMD3<Float> {
    /// 벡터의 길이
    var length: Float {
        return sqrt(x * x + y * y + z * z)
    }
    
    /// 정규화된 벡터
    var normalized: SIMD3<Float> {
        let len = length
        return len > 0 ? self / len : SIMD3<Float>(0, 0, 0)
    }
    
    /// 외적(Cross Product)
    func cross(_ other: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }
    
    /// 내적(Dot Product)
    func dot(_ other: SIMD3<Float>) -> Float {
        return x * other.x + y * other.y + z * other.z
    }
}

