import Cocoa
import MetalKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    let windowDelegate = WindowDelegate()
    
    let device = MTLCreateSystemDefaultDevice()
    let mtkView = MTKView()
    var renderer: Renderer!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window.delegate = windowDelegate

        mtkView.translatesAutoresizingMaskIntoConstraints = false
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.layer?.allowsEdgeAntialiasing = true
        
        window.contentView = mtkView

        renderer = Renderer(view: mtkView, device: device!)
        mtkView.delegate = renderer
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(self)
    }
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let mtkView: MTKView
    let library: MTLLibrary
    
    let vert: MTLFunction
    let frag: MTLFunction
    
    var captured = true
    
    init(view: MTKView, device: MTLDevice) {
        self.device = device
        self.mtkView = view
        self.library = device.makeDefaultLibrary()!
        
        vert = library.makeFunction(name: "rect_vertex_shader")!
        frag = library.makeFunction(name: "rect_fragment_shader")!

        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func triggerProgrammaticCapture() {
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = self.device
        do {
            try captureManager.startCapture(with: captureDescriptor)
        } catch {
            fatalError("error when trying to capture: \(error)")
        }
    }
    
    func draw(in view: MTKView) {
        let pipelineState = makePipelineState()
        let commandQueue = device.makeCommandQueue()
        
        var rectUniforms = PerRectUniforms(
            size: SIMD2(200, 100),
            origin: SIMD2(20, 20),
            background_color: SIMD4(0.8, 0.8, 0.8, 1.0),
            border_size: SIMD4(1.0, 1.0, 1.0, 1.0),
            border_color: SIMD4(0.0, 0.0, 0.0, 1.0),
            corner_radius: 8
        )
        let rectUniformsBuffer = device.makeBuffer(
            bytes: &rectUniforms,
            length: MemoryLayout<PerRectUniforms>.stride,
            options: [.storageModeShared, .storageModeManaged]
        )
        
        let physicalSize = mtkView.drawableSize
        var uniforms = Uniforms(viewport_size: SIMD2(Float(physicalSize.width), Float(physicalSize.height)))
        let uniformsBuffer = device.makeBuffer(
            bytes: &uniforms,
            length: MemoryLayout<Uniforms>.stride,
            options: [.storageModeShared, .storageModeManaged]
        )
        
        let vertexData: [Float] = [
            0.0, 0.0, // top left
            1.0, 0.0, // top right
            1.0, 1.0, // bottom right
            1.0, 1.0,
            0.0, 1.0,
            0.0, 0.0,
        ]
        let vertexBuffer = device.makeBuffer(
            bytes: vertexData,
            length: vertexData.count * MemoryLayout<Float>.stride,
            options: [.storageModeShared, .storageModeManaged]
        )
        
        guard let layer = view.layer as? CAMetalLayer else { fatalError("Cannot retrieve metal layer") }
        guard let drawable = layer.nextDrawable() else { return }
        
        var renderPassDescriptor = MTLRenderPassDescriptor()
        prepareRenderPassDescriptor(&renderPassDescriptor, drawable.texture)
        
        if (!captured) {
            triggerProgrammaticCapture()
        }
        
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        encoder.setScissorRect(.init(x: 0, y: 0, width: Int(physicalSize.width), height: Int(physicalSize.height)))
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(rectUniformsBuffer, offset: 0, index: 1)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexData.count / 2)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        if (!captured) {
            let captureManager = MTLCaptureManager.shared()
            captureManager.stopCapture()
            captured = true
        }
    }
    
    private func makePipelineState() -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vert
        descriptor.fragmentFunction = frag
        
        let attachment = descriptor.colorAttachments[0]
        attachment?.pixelFormat = .bgra8Unorm
        attachment?.isBlendingEnabled = true
        attachment?.rgbBlendOperation = .add
        attachment?.alphaBlendOperation = .add
        attachment?.sourceRGBBlendFactor = .sourceAlpha
        attachment?.sourceAlphaBlendFactor = .sourceAlpha
        attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError("Failed to make render pipeline state: \(error.localizedDescription)")
        }
    }
    
    private func prepareRenderPassDescriptor(_ descriptor: inout MTLRenderPassDescriptor, _ texture: MTLTexture) {
        let colorAttachment = descriptor.colorAttachments[0]
        
        colorAttachment?.texture = texture
        colorAttachment?.loadAction = .clear
        colorAttachment?.clearColor = .init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        colorAttachment?.storeAction = .store
    }
}
