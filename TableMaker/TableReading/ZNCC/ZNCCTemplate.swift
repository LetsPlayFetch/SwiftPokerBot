import Foundation

struct ZNCCTemplateMeta: Codable {
    let id: String
    let label: String
    let size: [Int]        // [w, h]
    let sigma: Float       // std dev of template (required)
    let threshold: Float   // start ~0.80; tune per-label
    let version: String
    let notes: String?
}

struct ZNCCTemplate {
    let id: String
    let label: String
    let w: Int, h: Int
    let zeroMean: [Float]  // length = w*h, zero-mean
    let sigma: Float
    let threshold: Float
}

enum ZNCCIO {
    static func loadTemplate(at folder: URL) throws -> ZNCCTemplate {
        let jsonURL = folder.appendingPathComponent("meta.json")
        let binURL  = folder.appendingPathComponent("pixels.bin")
        let meta = try JSONDecoder().decode(ZNCCTemplateMeta.self, from: Data(contentsOf: jsonURL))
        let w = meta.size[0], h = meta.size[1]
        let count = w*h
        let bin = try Data(contentsOf: binURL)
        let floats: [Float] = bin.withUnsafeBytes { raw in
            let ptr = raw.bindMemory(to: Float.self)
            return Array(ptr)
        }
        guard floats.count == count else { 
            throw NSError(domain: "ZNCC", code: 2, userInfo: [NSLocalizedDescriptionKey:"Bin size mismatch"]) 
        }
        return ZNCCTemplate(id: meta.id, label: meta.label, w: w, h: h,
                            zeroMean: floats, sigma: meta.sigma, threshold: meta.threshold)
    }
    
    static func saveTemplate(_ t: ZNCCTemplate, at folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // pixels
        let binURL = folder.appendingPathComponent("pixels.bin")
        try t.zeroMean.withUnsafeBytes { try Data($0).write(to: binURL) }
        // meta
        let meta = ZNCCTemplateMeta(id: t.id, label: t.label, size: [t.w,t.h],
                                    sigma: t.sigma, threshold: t.threshold,
                                    version: "v1", notes: nil)
        let jsonURL = folder.appendingPathComponent("meta.json")
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(meta).write(to: jsonURL)
    }
}
