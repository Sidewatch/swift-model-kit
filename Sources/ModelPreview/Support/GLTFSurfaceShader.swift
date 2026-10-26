//
//  GLTFSurfaceShader.swift
//  ModelPreview
//
//  The surface shader every glTF material is drawn with: base colour and alpha as the spec defines them.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader
import SceneKit

/// A glTF material's base colour and alpha, done in SceneKit's surface stage, before lighting.
///
/// SceneKit hands the surface stage a texture or a vertex colour premultiplied by its alpha, but a
/// plain colour straight (measured), so the material's diffuse is only ever the texture or opaque
/// white, and the base colour factor comes in as an argument. The shader divides the alpha back out,
/// multiplies by the factor (glTF 5.22.1: a linear multiplier of the texels, so before lighting, and
/// never of the emission), then applies the alpha mode (3.9.4): `OPAQUE` ignores alpha, `MASK` draws
/// fragments at or over the cutoff fully opaque and drops the rest, `BLEND` premultiplies again for
/// SceneKit's "over". An emissive texture is scaled by its factor (5.19.8).
struct GLTFSurfaceShader {
    var alphaMode: GLTFAlphaMode
    var baseColorFactor: SIMD4<Float>
    var alphaCutoff: Float
    /// The emissive texture's multiplier (factor × strength); nil when the emission has no texture.
    var emissiveFactor: SIMD3<Float>?

    init(alphaMode: GLTFAlphaMode, baseColorFactor: SIMD4<Float>, alphaCutoff: Float, emissiveFactor: SIMD3<Float>? = nil) {
        self.alphaMode = alphaMode
        self.baseColorFactor = baseColorFactor
        self.alphaCutoff = alphaCutoff
        self.emissiveFactor = emissiveFactor
    }

    /// The shader modifier's source: argument declarations, then the body.
    var source: String {
        var arguments = ["float4 sw_baseColorFactor;"]
        var body = [
            "float sw_a = _surface.diffuse.a;",
            "float3 sw_rgb = sw_a > 0.0 ? _surface.diffuse.rgb / sw_a : float3(0.0);",
            "sw_rgb *= sw_baseColorFactor.rgb;",
            "sw_a *= sw_baseColorFactor.a;",
        ]
        switch alphaMode {
        case .opaque:
            body.append("_surface.diffuse = float4(sw_rgb, 1.0);")
        case .mask:
            arguments.append("float sw_alphaCutoff;")
            body.append("if (sw_a < sw_alphaCutoff) { discard_fragment(); }")
            body.append("_surface.diffuse = float4(sw_rgb, 1.0);")
        case .blend:
            body.append("_surface.diffuse = float4(sw_rgb * sw_a, sw_a);")
        }
        if emissiveFactor != nil {
            arguments.append("float3 sw_emissiveFactor;")
            body.append("_surface.emission.rgb *= sw_emissiveFactor;")
        }
        return "#pragma arguments\n" + arguments.joined(separator: "\n") + "\n#pragma body\n" + body.joined(separator: "\n")
    }

    /// Sets the shader, its arguments and the blending its alpha mode needs on `material`.
    func apply(to material: SCNMaterial) {
        material.shaderModifiers = [.surface: source]
        let f = baseColorFactor
        material.setValue(
            NSValue(scnVector4: SCNVector4(CGFloat(f.x), CGFloat(f.y), CGFloat(f.z), CGFloat(f.w))), forKey: "sw_baseColorFactor")
        switch alphaMode {
        case .opaque:
            material.blendMode = .replace
        case .mask:
            material.blendMode = .replace
            material.setValue(NSNumber(value: alphaCutoff), forKey: "sw_alphaCutoff")
        case .blend:
            material.blendMode = .alpha
            material.transparencyMode = .dualLayer
        }
        if let e = emissiveFactor {
            material.setValue(NSValue(scnVector3: SCNVector3(CGFloat(e.x), CGFloat(e.y), CGFloat(e.z))), forKey: "sw_emissiveFactor")
        }
    }
}
