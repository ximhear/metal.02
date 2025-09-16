import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    @Binding var projectionMode: ProjectionMode
    @Binding var showDebugInfo: Bool
    
    enum ProjectionMode {
        case orthographic
        case perspective
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
        mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.projectionMode = projectionMode
        context.coordinator.renderer?.isDebugMode = showDebugInfo
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalView
        var renderer: Renderer?
        
        init(_ parent: MetalView) {
            self.parent = parent
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }
        
        func draw(in view: MTKView) {
            renderer?.draw(in: view)
        }
    }
}
