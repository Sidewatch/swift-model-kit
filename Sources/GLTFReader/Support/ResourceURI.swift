//
//  ResourceURI.swift
//  GLTFReader
//
//  The bytes a buffer's or an image's URI names: a data URI, or a file in the model's folder.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The bytes a buffer's or image's URI names. A `data:` URI carries them (base64, or percent-encoded
/// text); any other URI is a relative path, percent-decoded, read from the model's folder or below
/// it. An absolute path, a URL with a scheme, a path that climbs out of the folder (`../`) and a
/// model read without a folder name nothing.
enum ResourceURI {
    static func data(_ uri: String, folder: URL?) -> Data? {
        if uri.hasPrefix("data:") { return dataURI(uri) }
        guard let folder, !uri.hasPrefix("/"), !uri.contains("://"), let path = uri.removingPercentEncoding else { return nil }
        let base = folder.standardizedFileURL
        let file = base.appendingPathComponent(path).standardizedFileURL
        guard file.path.hasPrefix(base.path.hasSuffix("/") ? base.path : base.path + "/") else { return nil }
        return try? Data(contentsOf: file, options: .mappedIfSafe)
    }

    /// The payload of `data:[<type>][;base64],<payload>`.
    private static func dataURI(_ uri: String) -> Data? {
        guard let comma = uri.firstIndex(of: ",") else { return nil }
        let header = uri[uri.index(uri.startIndex, offsetBy: 5)..<comma]
        let payload = String(uri[uri.index(after: comma)...])
        if header.hasSuffix(";base64") { return Data(base64Encoded: payload, options: .ignoreUnknownCharacters) }
        return payload.removingPercentEncoding.map { Data($0.utf8) }
    }
}
