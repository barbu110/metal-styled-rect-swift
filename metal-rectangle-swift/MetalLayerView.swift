//
//  MetalLayerView.swift
//  metal-rectangle-swift
//
//  Created by Victor Barbu on 22.05.2023.
//

import Cocoa

class MetalLayerView: NSView, CALayerDelegate {
    var renderer: Renderer
    var metalLayer: CAMetalLayer!
    
    override init(frame: NSRect) {
        let device = MTLCreateSystemDefaultDevice()!
        renderer = Renderer(pixelFormat: .bgra8Unorm, device: device)
        
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .duringViewResize
        self.layerContentsPlacement = .scaleAxesIndependently
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func makeBackingLayer() -> CALayer {
        metalLayer = CAMetalLayer()
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.device = renderer.device
        metalLayer.delegate = self
        metalLayer.allowsNextDrawableTimeout = false
        metalLayer.autoresizingMask = CAAutoresizingMask(arrayLiteral: [.layerHeightSizable, .layerWidthSizable])
        metalLayer.needsDisplayOnBoundsChange = true
        metalLayer.presentsWithTransaction = true
        
        return metalLayer
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
        renderer.uniforms.viewport_size = SIMD2<Float>(Float(newSize.width), Float(newSize.height))
        metalLayer.drawableSize = convertToBacking(newSize)
        self.viewDidChangeBackingProperties()
    }
    
    override func viewDidChangeBackingProperties() {
        guard let window = self.window else { return }
        metalLayer.contentsScale = window.backingScaleFactor
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    func display(_ layer: CALayer) {
        let drawable = metalLayer.nextDrawable()!
        let passDescriptor = MTLRenderPassDescriptor()
        let colorAttachment = passDescriptor.colorAttachments[0]!

        colorAttachment.texture = drawable.texture
        colorAttachment.loadAction = .clear
        colorAttachment.storeAction = .store
        colorAttachment.clearColor = .init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        
        let rectUniforms = PerRectUniforms(size: vector2(256, 128), origin: vector2(32, 32),
                                           background_color: vector4(0.4, 0.4, 0.4, 1.0),
                                           border_size: vector4(1, 1, 1, 1),
                                           border_color: vector4(0, 0, 0, 1.0),
                                           corner_radius: 8)
        let commandBuffer: MTLCommandBuffer = renderer.draw(passDescriptor: passDescriptor, rectUniforms: rectUniforms)!
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        drawable.present()
    }
    
}
