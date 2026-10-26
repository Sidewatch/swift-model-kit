//
//  GLTFSceneBuilder+Materials.swift
//  ModelPreview
//
//  glTF's metallic-roughness materials as SceneKit's physically based ones, textures decoded.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader
import ImageIO
import SceneKit

extension GLTFSceneBuilder {
    /// Material `index` as SceneKit's physically based material, built once however many primitives
    /// use it; glTF's default (white, fully metallic and rough) when the primitive names none.
    func material(_ index: Int?) throws -> SCNMaterial {
        guard let index else { return Self.defaultMaterial() }
        if let built = materials[index] { return built }
        guard let all = file.document.materials, all.indices.contains(index) else { throw GLTFError.outOfRange("Material \(index)") }
        let source = all[index]
        let material = SCNMaterial()
        material.name = source.name
        material.lightingModel = .physicallyBased
        material.isDoubleSided = source.doubleSided ?? false
        let pbr = source.pbrMetallicRoughness
        applyBaseColor(pbr, to: material)
        applyMetallicRoughness(pbr, to: material)
        if let normal = source.normalTexture, let image = image(forTexture: normal.index) {
            configure(material.normal, image, normal)
            material.normal.intensity = CGFloat(normal.scale ?? 1)
        }
        if let occlusion = source.occlusionTexture, let image = image(forTexture: occlusion.index) {
            configure(material.ambientOcclusion, image, occlusion)
            material.ambientOcclusion.textureComponents = .red
            material.ambientOcclusion.intensity = CGFloat(occlusion.strength ?? 1)
        }
        applyEmission(source, to: material)
        applyAlpha(source, to: material)
        materials[index] = material
        return material
    }

    /// The base colour: the texture times the factor (SceneKit's `multiply`), or the factor alone.
    private func applyBaseColor(_ pbr: GLTFPBRMetallicRoughness?, to material: SCNMaterial) {
        let factor = pbr?.baseColorFactor ?? [1, 1, 1, 1]
        if let texture = pbr?.baseColorTexture, let image = image(forTexture: texture.index) {
            configure(material.diffuse, image, texture)
            if factor != [1, 1, 1, 1] { material.multiply.contents = Self.linearColor(factor) }
        } else {
            material.diffuse.contents = Self.linearColor(factor)
        }
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

    /// Emission: the texture, or the emissive factor when it is not black.
    private func applyEmission(_ source: GLTFMaterial, to material: SCNMaterial) {
        if let emissive = source.emissiveTexture, let image = image(forTexture: emissive.index) {
            configure(material.emission, image, emissive)
        } else if let factor = source.emissiveFactor, factor.count == 3, factor.contains(where: { $0 > 0 }) {
            material.emission.contents = Self.linearColor(factor + [1])
        }
    }

    /// `BLEND` blends by alpha; `MASK` drops fragments under the cutoff; `OPAQUE` ignores alpha.
    private func applyAlpha(_ source: GLTFMaterial, to material: SCNMaterial) {
        switch GLTFAlphaMode(rawValue: source.alphaMode ?? "OPAQUE") ?? .opaque {
        case .blend:
            material.blendMode = .alpha
            material.transparencyMode = .dualLayer
        case .mask:
            let cutoff = source.alphaCutoff ?? 0.5
            material.shaderModifiers = [.fragment: "if (_output.color.a < \(cutoff)) { discard_fragment(); }"]
        case .opaque:
            material.blendMode = .replace
        }
    }

    /// Puts `image` in `property` with the texture's sampler and coordinate set.
    private func configure(_ property: SCNMaterialProperty, _ image: CGImage, _ info: GLTFTextureInfo) {
        property.contents = image
        property.mappingChannel = info.texCoord ?? 0
        let sampler = file.document.textures?[safe: info.index]?.sampler.flatMap { file.document.samplers?[safe: $0] }
        property.wrapS = Self.wrap(sampler?.wrapS)
        property.wrapT = Self.wrap(sampler?.wrapT)
        property.magnificationFilter = sampler?.magFilter == 9728 ? .nearest : .linear
        property.minificationFilter = [9728, 9984, 9986].contains(sampler?.minFilter ?? 0) ? .nearest : .linear
        property.mipFilter = [9728, 9729].contains(sampler?.minFilter ?? 0) ? .none : .linear
    }

    /// The decoded image of texture `index`, decoded once; nil when the texture, its image or the
    /// bytes are missing or not a picture ImageIO reads.
    func image(forTexture index: Int) -> CGImage? {
        guard let source = file.document.textures?[safe: index]?.source else { return nil }
        if let decoded = images[source] { return decoded }
        let decoded = (try? file.imageData(source)).flatMap { data -> CGImage? in
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        }
        images[source] = decoded
        return decoded
    }

    private static func wrap(_ code: Int?) -> SCNWrapMode {
        switch code {
        case 33071: .clamp
        case 33648: .mirror
        default: .repeat
        }
    }

    /// glTF's colours are linear sRGB.
    static func linearColor(_ rgba: [Float]) -> CGColor {
        let c = (rgba + [1, 1, 1, 1]).prefix(4).map { CGFloat($0) }
        return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!, components: Array(c)) ?? CGColor(gray: 1, alpha: 1)
    }

    /// The material a primitive without one is drawn with: white, fully metallic and rough.
    static func defaultMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = linearColor([1, 1, 1, 1])
        material.metalness.contents = NSNumber(value: 1.0)
        material.roughness.contents = NSNumber(value: 1.0)
        return material
    }
}
