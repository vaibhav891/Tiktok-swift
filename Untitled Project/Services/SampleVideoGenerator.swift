import Foundation
import AVFoundation
import CoreGraphics
import UIKit

/// Generates smooth, high-definition 9:16 vertical TikTok-style sample videos locally on device or simulator.
/// This guarantees 0ms buffering, instant playback, and zero network/CORS/403 failure dependencies.
public final class SampleVideoGenerator {
    public static let shared = SampleVideoGenerator()

    private init() {}

    /// Pre-generates all default sample videos if they don't already exist on disk.
    public func ensureSampleVideosExist() -> [URL] {
        let v1 = getOrCreateVideo(
            filename: "neon_sunset.mp4",
            colorA: UIColor(red: 0.95, green: 0.25, blue: 0.45, alpha: 1.0), // Neon pink
            colorB: UIColor(red: 0.45, green: 0.15, blue: 0.85, alpha: 1.0), // Deep purple
            title: "Neon Sunset"
        )

        let v2 = getOrCreateVideo(
            filename: "ocean_flow.mp4",
            colorA: UIColor(red: 0.05, green: 0.75, blue: 0.85, alpha: 1.0), // Cyan
            colorB: UIColor(red: 0.10, green: 0.30, blue: 0.95, alpha: 1.0), // Cobalt blue
            title: "Ocean Flow"
        )

        let v3 = getOrCreateVideo(
            filename: "cyber_grid.mp4",
            colorA: UIColor(red: 0.10, green: 0.90, blue: 0.60, alpha: 1.0), // Emerald mint
            colorB: UIColor(red: 0.05, green: 0.20, blue: 0.40, alpha: 1.0), // Dark navy
            title: "Cyber Pulse"
        )

        return [v1, v2, v3].compactMap { $0 }
    }

    /// Returns the cached file URL or writes a new MP4 video to the application cache directory.
    public func getOrCreateVideo(filename: String, colorA: UIColor, colorB: UIColor, title: String) -> URL? {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let fileURL = cachesDir.appendingPathComponent(filename)

        // Return if already cached and valid size
        if FileManager.default.fileExists(atPath: fileURL.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64, size > 10000 {
            return fileURL
        }

        try? FileManager.default.removeItem(at: fileURL)

        guard let writer = try? AVAssetWriter(outputURL: fileURL, fileType: .mp4) else {
            return nil
        }

        let width = 720
        let height = 1280
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        guard writer.canAdd(writerInput) else { return nil }
        writer.add(writerInput)

        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let totalFrames: Int32 = 90 // 3.0 second seamless loop

        var pixelBufferPool = adaptor.pixelBufferPool
        if pixelBufferPool == nil {
            var newPool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                nil,
                sourcePixelBufferAttributes as CFDictionary,
                &newPool
            )
            pixelBufferPool = newPool
        }

        for frame in 0..<totalFrames {
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }

            var pixelBuffer: CVPixelBuffer?
            if let pool = pixelBufferPool {
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            }
            if pixelBuffer == nil {
                CVPixelBufferCreate(
                    kCFAllocatorDefault,
                    width,
                    height,
                    kCVPixelFormatType_32ARGB,
                    sourcePixelBufferAttributes as CFDictionary,
                    &pixelBuffer
                )
            }

            guard let buffer = pixelBuffer else { continue }

            CVPixelBufferLockBaseAddress(buffer, [])
            if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
                let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                )

                if let ctx = context {
                    let progress = CGFloat(frame) / CGFloat(totalFrames)

                    // Moving animated gradient
                    let colors = [colorA.cgColor, colorB.cgColor, colorA.cgColor] as CFArray
                    let locations: [CGFloat] = [0.0, 0.5 + 0.3 * sin(progress * .pi * 2), 1.0]
                    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                        let startY = CGFloat(height) * (0.2 + 0.3 * sin(progress * .pi * 2))
                        ctx.drawLinearGradient(
                            gradient,
                            start: CGPoint(x: 0, y: startY),
                            end: CGPoint(x: CGFloat(width), y: CGFloat(height)),
                            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                        )
                    }

                    // Floating animated glowing rings / orbs
                    let orbY = CGFloat(height) * 0.45 + sin(progress * .pi * 2) * 60.0
                    let orbX = CGFloat(width) * 0.5 + cos(progress * .pi * 2) * 30.0
                    let orbRadius: CGFloat = 130.0 + 20.0 * sin(progress * .pi * 2)

                    // Outer soft glow
                    ctx.setFillColor(UIColor.white.withAlphaComponent(0.12).cgColor)
                    ctx.fillEllipse(in: CGRect(x: orbX - orbRadius * 1.5, y: orbY - orbRadius * 1.5, width: orbRadius * 3, height: orbRadius * 3))

                    // Inner circle
                    ctx.setFillColor(UIColor.white.withAlphaComponent(0.25).cgColor)
                    ctx.fillEllipse(in: CGRect(x: orbX - orbRadius, y: orbY - orbRadius, width: orbRadius * 2, height: orbRadius * 2))

                    // Sharp stroke ring
                    ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor)
                    ctx.setLineWidth(5.0)
                    ctx.strokeEllipse(in: CGRect(x: orbX - orbRadius, y: orbY - orbRadius, width: orbRadius * 2, height: orbRadius * 2))
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])

            let frameTime = CMTime(value: Int64(frame), timescale: fps)
            adaptor.append(buffer, withPresentationTime: frameTime)
        }

        writerInput.markAsFinished()

        let group = DispatchGroup()
        group.enter()
        writer.finishWriting {
            group.leave()
        }
        group.wait()

        return fileURL
    }
}
