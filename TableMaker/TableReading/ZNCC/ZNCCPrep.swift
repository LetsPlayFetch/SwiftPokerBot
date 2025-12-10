import Accelerate
import AppKit
import CoreImage
import CoreGraphics

// MARK: - Prep: NSImage/CIImage -> grayscale Float [0..1]
enum ZNCCPrep {
    static func grayscaleFloat(from cg: CGImage, width: Int, height: Int) -> [Float] {
        // Draw into an 8-bit gray context, then scale to Float
        let cs = CGColorSpaceCreateDeviceGray()
        var u8 = [UInt8](repeating: 0, count: width*height)
        u8.withUnsafeMutableBytes { ptr in
            let ctx = CGContext(data: ptr.baseAddress, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width,
                                space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            ctx.interpolationQuality = .high
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var f = [Float](repeating: 0, count: u8.count)
        vDSP.convertElements(of: u8, to: &f)
        var scl: Float = 1.0/255.0
        vDSP.multiply(scl, f, result: &f)
        return f
    }

    static func cgImage(from ns: NSImage) -> CGImage? {
        var r = CGRect(origin: .zero, size: ns.size)
        return ns.cgImage(forProposedRect: &r, context: nil, hints: nil)
    }
}

// MARK: - Integral images (sum and sum of squares)
fileprivate func integralD(_ a: [Float], w: Int, h: Int) -> [Double] {
    var S = [Double](repeating: 0, count: (w+1)*(h+1))
    for y in 1...h {
        var rowsum = 0.0
        let iy = (y-1)*w
        let sy = y*(w+1)
        for x in 1...w {
            rowsum += Double(a[iy + (x-1)])
            S[sy + x] = S[(sy - (w+1)) + x] + rowsum
        }
    }
    return S
}
fileprivate func rectSum(_ S:[Double], w:Int, x:Int,y:Int, ww:Int,hh:Int) -> Double {
    let W = w+1, x2 = x+ww, y2 = y+hh
    return S[y*W + x] + S[y2*W + x2] - S[y*W + x2] - S[y2*W + x]
}

// MARK: - Match result
struct ZNCCMatch {
    let label: String
    let templateId: String
    let point: CGPoint  // top-left in ROI coords
    let score: Float    // 0.0..1.0 (higher is better, normalized)
}

// MARK: - Core matcher
enum ZNCCMatcher {
    /// Find best match of any template inside an ROI image (already cropped)
    static func bestMatch(
        roiNSImage: NSImage,
        templates: [ZNCCTemplate],
        stride: Int = 2,
        refineRadius: Int = 3
    ) -> ZNCCMatch? {

        guard let cg = ZNCCPrep.cgImage(from: roiNSImage) else { return nil }
        let roiW = cg.width, roiH = cg.height
        var best: (score: Float, x: Int, y: Int, t: ZNCCTemplate)?

        // Prepare floats and integrals once per ROI
        let imgF = ZNCCPrep.grayscaleFloat(from: cg, width: roiW, height: roiH)
        let S  = integralD(imgF, w: roiW, h: roiH)

        var imgF2 = [Float](repeating: 0, count: imgF.count)
        vDSP_vsq(imgF, 1, &imgF2, 1, vDSP_Length(imgF.count))
        let S2 = integralD(imgF2, w: roiW, h: roiH)

        // Scan each template (take the maximum score across the bank)
        for T in templates {
            if T.w > roiW || T.h > roiH { continue }

            let sw = max(roiW - T.w + 1, 0)
            let sh = max(roiH - T.h + 1, 0)

            // Pass 1: coarse
            var passBest: (Float, Int, Int)? = nil
            var y = 0
            while y < sh {
                var x = 0
                while x < sw {
                    if let sc = znccAt(x: x, y: y, imgF: imgF, roiW: roiW, roiH: roiH, S: S, S2: S2, T: T) {
                        if passBest == nil || sc > passBest!.0 {
                            passBest = (sc, x, y)
                        }
                    }
                    x += stride
                }
                y += stride
            }

            // Pass 2: refine around best (stride=1 in small window)
            if let pb = passBest {
                let rx0 = max(0, pb.1 - refineRadius)
                let rx1 = min(sw-1, pb.1 + refineRadius)
                let ry0 = max(0, pb.2 - refineRadius)
                let ry1 = min(sh-1, pb.2 + refineRadius)
                for yy in ry0...ry1 {
                    for xx in rx0...rx1 {
                        if let sc = znccAt(x: xx, y: yy, imgF: imgF, roiW: roiW, roiH: roiH, S: S, S2: S2, T: T) {
                            if best == nil || sc > best!.score {
                                best = (sc, xx, yy, T)
                            }
                        }
                    }
                }
            }
        }

        if let b = best {
            return ZNCCMatch(label: b.t.label, templateId: b.t.id,
                             point: CGPoint(x: b.x, y: b.y),
                             score: b.score)
        }
        return nil
    }

    /// Single-position ZNCC with proper normalization
    private static func znccAt(
        x: Int, y: Int,
        imgF: [Float], roiW: Int, roiH: Int,
        S: [Double], S2: [Double],
        T: ZNCCTemplate
    ) -> Float? {
        let tw = T.w, th = T.h, n = Float(tw*th)

        // Local mean and std in O(1)
        let sumI  = rectSum(S,  w: roiW, x: x, y: y, ww: tw, hh: th)
        let sumI2 = rectSum(S2, w: roiW, x: x, y: y, ww: tw, hh: th)
        let muI   = Float(sumI) / n
        let varI  = max(Float(sumI2)/n - muI*muI, 1e-12)
        let sigI  = sqrtf(varI)
        
        // More aggressive flat region check for binary images
        if sigI < 1e-3 { return nil }

        // Dot product (I, T')
        var dot: Float = 0
        for ry in 0..<th {
            let baseI = (y+ry)*roiW + x
            imgF.withUnsafeBufferPointer { ib in
                T.zeroMean.withUnsafeBufferPointer { tb in
                    var s: Float = 0
                    vDSP_dotpr(ib.baseAddress! + baseI, 1,
                               tb.baseAddress! + ry*tw, 1,
                               &s, vDSP_Length(tw))
                    dot += s
                }
            }
        }

        let denom = sigI * T.sigma
        guard denom > 1e-6 else { return nil }
        
        let rawScore = dot / denom
        
        // FIXED: Normalize by template pixel count
        // For binary/high-contrast images, raw score ≈ pixel count
        // Normalizing gives us proper 0.0-1.0 range
        let normalizedScore = rawScore / n
        
        // Clamp to valid range [0, 1]
        return max(0.0, min(1.0, normalizedScore))
    }
}
