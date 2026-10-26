//
//  GLTFSceneBuilder+Materials.swift
//  ModelPreview
//
//  glTF materials as SceneKit's physically based (or unlit) materials, with their textures.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader
import ImageIO
import SceneKit

extension GLTFSceneBuilder {
    /// Material `index` as SceneKit's physically based material, built once however many primitives use
    /// it; glTF's default (white, fully metallic and rough) when the primitive names none. `unlit` draws
    /// it with its base colour alone, as `KHR_materials_unlit` does and as points and lines without
    /// normals are drawn.
    func material(_ index: Int?, unlit: Bool = false) throws -> SCNMaterial {
        let key = MaterialKey(index: index, unlit: unlit)
        if let built = materials[key] { return built }
        let source: GLTFMaterial?
        if let index {
            guard let all = file.document.materials, all.indices.contains(index) else { throw GLTFError.outOfRange("Material \(index)") }
            source = all[index]
        } else {
            source = nil
        }
        let material = build(source, unlit: unlit || source?.extensions?.unlit != nil)
        materials[key] = material
        return material
    }

    /// A material from `source` (nil for glTF's default). Everything about the base colour and its
    /// alpha is done by one surface shader (``GLTFSurfaceShader``), so the factor applies before
    /// lighting and the alpha mode is the spec's; an unlit material keeps only its base colour.
    private func build(_ source: GLTFMaterial?, unlit: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.name = source?.name
        material.lightingModel = unlit ? .constant : .physicallyBased
        material.isDoubleSided = source?.doubleSided ?? false
        let pbr = source?.pbrMetallicRoughness
        if let texture = pbr?.baseColorTexture, let image = image(forTexture: texture.index) {
            configure(material.diffuse, image, texture)
        } else {
            material.diffuse.contents = Self.linearColor([1, 1, 1, 1])
        }
        var shader = GLTFSurfaceShader(
            alphaMode: GLTFAlphaMode(rawValue: source?.alphaMode ?? "OPAQUE") ?? .opaque,
            baseColorFactor: Self.vector4(pbr?.baseColorFactor, default: [1, 1, 1, 1]), alphaCutoff: source?.alphaCutoff ?? 0.5)
        if !unlit, let source {
            applyMetallicRoughness(pbr, to: material)
            applyNormalAndOcclusion(source, to: material)
            shader.emissiveFactor = applyEmission(source, to: material)
        } else if !unlit {
            material.metalness.contents = NSNumber(value: 1.0)
            material.roughness.contents = NSNumber(value: 1.0)
        }
        shader.apply(to: material)
        return material
    }

    /// Metalness and roughness: factors, or the texture's blue and green channels scaled by them.
    private func applyMetallicRoughness(_ pbr: GLTFPBRMetallicRoughness?, to material: SCNMaterial) {
        let metallic = CGFloat(pbr?.metallicFactor ?? 1)
        let roughness = CGFloat(pbr?.roughnessFactor ?? 1)
        if let texture = pbr?.metallicRoughnessTexture, let image = image(forTexture: texture.index) {
            configure(material.metalness, image, texture)
            material.metalness.textureComponents = .blue
            material.metalness.intensity = metallic
            configure(material.roughness, image, texture)
            material.roughness.textureComponents = .green
            material.roughness.intensity = roughness
        } else {
            material.metalness.contents = NSNumber(value: Double(metallic))
            material.roughness.contents = NSNumber(value: Double(roughness))
        }
    }

    /// The normal map at its scale, and occlusion from the red channel at its strength.
    private func applyNormalAndOcclusion(_ source: GLTFMaterial, to material: SCNMaterial) {
        if let normal = source.normalTexture, let image = image(forTexture: normal.index) {
            configure(material.normal, image, normal)
            material.normal.intensity = CGFloat(normal.scale ?? 1)
        }
        if let occlusion = source.occlusionTexture, let image = image(forTexture: occlusion.index) {
            configure(material.ambientOcclusion, image, occlusion)
            material.ambientOcclusion.textureComponents = .red
            material.ambientOcclusion.intensity = CGFloat(occlusion.strength ?? 1)
        }
    }

    /// Emission: the texture × the factor × `KHR_materials_emissive_strength` (glTF 5.19.8); nothing
    /// when the factor is black or absent, which is its default. A texture's multiplier is returned for
    /// the surface shader; a factor alone is the emission colour at the strength.
    private func applyEmission(_ source: GLTFMaterial, to material: SCNMaterial) -> SIMD3<Float>? {
        let factor = Self.vector3(source.emissiveFactor)
        guard factor != .zero else { return nil }
        let strength = source.extensions?.emissiveStrength?.emissiveStrength ?? 1
        if let emissive = source.emissiveTexture, let image = image(forTexture: emissive.index) {
            configure(material.emission, image, emissive)
            return factor * strength
        }
        material.emission.contents = Self.linearColor([factor.x, factor.y, factor.z, 1])
        material.emission.intensity = CGFloat(strength)
        return nil
    }

    /// Puts `image` in `property` with the texture's sampler, coordinate set and `KHR_texture_transform`.
    private func configure(_ property: SCNMaterialProperty, _ image: CGImage, _ info: GLTFTextureInfo) {
        property.contents = image
        let transform = info.extensions?.textureTransform
        property.mappingChannel = transform?.texCoord ?? info.texCoord ?? 0
        if let transform { property.contentsTransform = Self.contentsTransform(transform) }
        let sampler = file.document.textures?[safe: info.index]?.sampler.flatMap { file.document.samplers?[safe: $0] }
        property.wrapS = Self.wrap(sampler?.wrapS)
        property.wrapT = Self.wrap(sampler?.wrapT)
        property.magnificationFilter = sampler?.magFilter == 9728 ? .nearest : .linear
        let minFilter = sampler?.minFilter
        property.minificationFilter = [9728, 9984, 9986].contains(minFilter ?? 0) ? .nearest : .linear
        property.mipFilter = Self.mipFilter(minFilter)
    }

    /// `KHR_texture_transform`'s `translation × rotation × scale` applied to `(u, v, 1)`, as Khronos's reference
    /// renderer computes it (glTF-Sample-Renderer, `material.js` `updateTextureTransforms`) and its TextureTransformTest
    /// model checks it: `u' = cos·sx·u + sin·sy·v + ox`, `v' = −sin·sx·u + cos·sy·v + oy`. The extension README's GLSL
    /// listing has the rotation's sign the other way (glTF issue #1563, open); files are made and checked against the
    /// renderer, and with the README's sign that model's arrow points at its "applied in the opposite direction"
    /// marker (checked). SceneKit applies `contentsTransform` to `(u, v, 0, 1)` as a row vector (measured), so the
    /// terms go in by row.
    static func contentsTransform(_ transform: GLTFTextureTransform) -> SCNMatrix4 {
        let offset = transform.offset ?? [0, 0]
        let scale = transform.scale ?? [1, 1]
        let (ox, oy) = (CGFloat(offset[safe: 0] ?? 0), CGFloat(offset[safe: 1] ?? 0))
        let (sx, sy) = (CGFloat(scale[safe: 0] ?? 1), CGFloat(scale[safe: 1] ?? 1))
        let angle = CGFloat(transform.rotation ?? 0)
        var m = SCNMatrix4Identity
        m.m11 = cos(angle) * sx
        m.m21 = sin(angle) * sy
        m.m41 = ox
        m.m12 = -sin(angle) * sx
        m.m22 = cos(angle) * sy
        m.m42 = oy
        return m
    }

    /// The decoded image of texture `index`, decoded once: its `EXT_texture_webp` source when it has one
    /// that decodes, else its own; nil when the texture, its image or the bytes are missing or not a
    /// picture ImageIO reads.
    func image(forTexture index: Int) -> CGImage? {
        guard let texture = file.document.textures?[safe: index] else { return nil }
        for source in [texture.extensions?.webp?.source, texture.source].compactMap({ $0 }) {
            if let decoded = decodedImage(source) { return decoded }
        }
        return nil
    }

    /// Image `index`, decoded once by ImageIO; nil when it cannot be had or read.
    private func decodedImage(_ index: Int) -> CGImage? {
        if let decoded = images[index] { return decoded }
        let decoded = (try? file.imageData(index)).flatMap { data -> CGImage? in
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        }
        images[index] = decoded
        return decoded
    }

    private static func wrap(_ code: Int?) -> SCNWrapMode {
        switch code {
        case 33071: .clamp
        case 33648: .mirror
        default: .repeat
        }
    }

    /// The mip filter a minification filter asks for: none for NEAREST and LINEAR, nearest for the
    /// `…_MIPMAP_NEAREST` pair, linear for the `…_MIPMAP_LINEAR` pair and when it says nothing.
    static func mipFilter(_ code: Int?) -> SCNFilterMode {
        switch code {
        case 9728, 9729: .none
        case 9984, 9985: .nearest
        default: .linear
        }
    }

    /// glTF's colours are linear sRGB.
    static func linearColor(_ rgba: [Float]) -> CGColor {
        let c = (rgba + [1, 1, 1, 1]).prefix(4).map { CGFloat($0) }
        return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!, components: Array(c)) ?? CGColor(gray: 1, alpha: 1)
    }

    /// Four floats from a file's array, `default` when it does not have exactly four.
    static func vector4(_ values: [Float]?, default fallback: SIMD4<Float>) -> SIMD4<Float> {
        guard let values, values.count == 4 else { return fallback }
        return SIMD4(values[0], values[1], values[2], values[3])
    }

    /// Three floats from a file's array, zero when it does not have exactly three.
    static func vector3(_ values: [Float]?) -> SIMD3<Float> {
        guard let values, values.count == 3 else { return .zero }
        return SIMD3(values[0], values[1], values[2])
    }
}
