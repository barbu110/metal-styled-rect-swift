//
//  Renderer.swift
//  metal-rectangle-swift
//
//  Created by Victor Barbu on 22.05.2023.
//

import Cocoa
import MetalKit

class Renderer {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState!
    var uniforms: Uniforms = Uniforms(viewport_size: vector2(0, 0))
    
    init(pixelFormat: MTLPixelFormat, device: MTLDevice) {
        self.device = device
        
        commandQueue = device.makeCommandQueue()!
        do {
            let library = device.makeDefaultLibrary()
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library?.makeFunction(name: "rect_vertex_shader")
            descriptor.fragmentFunction = library?.makeFunction(name: "rect_fragment_shader")
            
            let attachment = descriptor.colorAttachments[0]
            attachment?.pixelFormat = .bgra8Unorm
            attachment?.isBlendingEnabled = true
            attachment?.rgbBlendOperation = .add
            attachment?.alphaBlendOperation = .add
            attachment?.sourceRGBBlendFactor = .sourceAlpha
            attachment?.sourceAlphaBlendFactor = .sourceAlpha
            attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create pipeline state")
        }
    }

    func draw(passDescriptor: MTLRenderPassDescriptor, rectUniforms: PerRectUniforms) -> MTLCommandBuffer? {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return nil }

        var vertexData: [Float] = [
            0.0, 0.0, // top left
            1.0, 0.0, // top right
            1.0, 1.0, // bottom right
            1.0, 1.0,
            0.0, 1.0,
            0.0, 0.0,
        ]
        var rectUniformsMut = rectUniforms
        encoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setVertexBytes(&rectUniformsMut, length: MemoryLayout<PerRectUniforms>.stride, index: 1)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexData.count / 2)
        encoder.endEncoding()

        return commandBuffer
    }
}
