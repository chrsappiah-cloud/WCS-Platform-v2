//
//  AVFoundationImageSequenceRenderer.swift
//  WCS-Platform
//
//  Deterministic scene clip renderer for image-sequence strategy.
//

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import UIKit

enum ImageSequenceRenderError: LocalizedError {
    case writerStartFailed
    case writerFailed(Error?)
    case pixelBufferPoolUnavailable
    case frameAppendFailed

    var errorDescription: String? {
        switch self {
        case .writerStartFailed:
            return "Could not start image-sequence video writer."
        case .writerFailed(let error):
            return "Image-sequence render failed: \(error?.localizedDescription ?? "unknown error")"
        case .pixelBufferPoolUnavailable:
            return "Pixel buffer pool unavailable for image-sequence render."
        case .frameAppendFailed:
            return "Could not append image-sequence frame."
        }
    }
}

enum ImageSequenceResolutionPreset: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case p720
    case p1080

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .p720: return CGSize(width: 1280, height: 720)
        case .p1080: return CGSize(width: 1920, height: 1080)
        }
    }

    var label: String {
        switch self {
        case .p720: return "720p"
        case .p1080: return "1080p"
        }
    }
}

enum DiagramOverlayStyle: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case none
    case flow
    case pulse

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .flow: return "Flow"
        case .pulse: return "Pulse"
        }
    }
}

struct ImageSequenceRenderSettings: Codable, Hashable, Sendable {
    var fps: Int32
    var resolution: ImageSequenceResolutionPreset
    var animationIntensity: Double
    var diagramStyle: DiagramOverlayStyle

    static let `default` = ImageSequenceRenderSettings(
        fps: 30,
        resolution: .p1080,
        animationIntensity: 1.0,
        diagramStyle: .flow
    )
}

struct AVFoundationImageSequenceRenderer {
    func renderPreviewFrame(
        scene: LessonVideoScenePlan,
        settings: ImageSequenceRenderSettings = .default,
        progress: CGFloat = 0.5
    ) async throws -> URL {
        let size = settings.resolution.size
        let referenceImage = await loadReferenceImage(for: scene)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            guard let ctx = UIGraphicsGetCurrentContext() else { return }
            drawFrame(
                scene: scene,
                frameIndex: Int(progress * 1000),
                frameCount: 1000,
                context: ctx,
                size: size,
                referenceImage: referenceImage,
                settings: settings
            )
        }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("wcs-image-seq-preview-\(scene.sceneId)-\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        if let data = image.jpegData(compressionQuality: 0.9) {
            try data.write(to: out, options: .atomic)
            return out
        }
        throw ImageSequenceRenderError.frameAppendFailed
    }

    func renderSceneClip(
        scene: LessonVideoScenePlan,
        settings: ImageSequenceRenderSettings = .default
    ) async throws -> URL {
        let size = settings.resolution.size
        let fps = settings.fps
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("wcs-image-seq-\(scene.sceneId)-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: out)

        let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
        guard writer.canAdd(input) else { throw ImageSequenceRenderError.writerStartFailed }
        writer.add(input)
        guard writer.startWriting() else { throw ImageSequenceRenderError.writerStartFailed }
        writer.startSession(atSourceTime: .zero)

        let referenceImage = await loadReferenceImage(for: scene)
        let duration = max(2, scene.durationSeconds ?? 8)
        let frameCount = Int(Double(duration) * Double(fps))

        guard let pool = adaptor.pixelBufferPool else {
            writer.cancelWriting()
            throw ImageSequenceRenderError.pixelBufferPoolUnavailable
        }

        for idx in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 2_000_000)
            }
            var maybeBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &maybeBuffer)
            guard let buffer = maybeBuffer else {
                writer.cancelWriting()
                throw ImageSequenceRenderError.frameAppendFailed
            }
            drawFrame(
                scene: scene,
                frameIndex: idx,
                frameCount: frameCount,
                into: buffer,
                size: size,
                referenceImage: referenceImage,
                settings: settings
            )
            let t = CMTime(value: Int64(idx), timescale: fps)
            if !adaptor.append(buffer, withPresentationTime: t) {
                writer.cancelWriting()
                throw ImageSequenceRenderError.frameAppendFailed
            }
        }

        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }
        guard writer.status == .completed else {
            throw ImageSequenceRenderError.writerFailed(writer.error)
        }
        return out
    }

    private func drawFrame(
        scene: LessonVideoScenePlan,
        frameIndex: Int,
        frameCount: Int,
        into buffer: CVPixelBuffer,
        size: CGSize,
        referenceImage: CGImage?,
        settings: ImageSequenceRenderSettings
    ) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        guard let ctx = CGContext(
            data: base,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return }
        drawFrame(
            scene: scene,
            frameIndex: frameIndex,
            frameCount: frameCount,
            context: ctx,
            size: size,
            referenceImage: referenceImage,
            settings: settings
        )
    }

    private func drawFrame(
        scene: LessonVideoScenePlan,
        frameIndex: Int,
        frameCount: Int,
        context ctx: CGContext,
        size: CGSize,
        referenceImage: CGImage?,
        settings: ImageSequenceRenderSettings
    ) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.setFillColor(UIColor.systemIndigo.cgColor)
        ctx.fill(rect)

        // Subtle deterministic pan-like shift for motion.
        let progress = CGFloat(frameIndex) / CGFloat(max(1, frameCount))
        let xOffset = progress * CGFloat(40 * settings.animationIntensity)
        let panel = CGRect(x: 80 + xOffset, y: 120, width: size.width - 160, height: size.height - 240)

        if let referenceImage {
            let imageRect = aspectFitRect(
                imageSize: CGSize(width: referenceImage.width, height: referenceImage.height),
                in: panel
            )
            ctx.saveGState()
            ctx.setAlpha(0.95)
            ctx.draw(referenceImage, in: imageRect)
            ctx.restoreGState()
        }

        ctx.setFillColor(UIColor.black.withAlphaComponent(0.25).cgColor)
        ctx.fill(panel)

        if scene.needsDiagram == true, settings.diagramStyle != .none {
            drawDiagramOverlay(in: panel, context: ctx, progress: progress, style: settings.diagramStyle)
        }

        let text = [
            scene.learningObjective ?? "Lesson Scene",
            scene.narrationText,
            scene.onScreenText ?? ""
        ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        let para = NSMutableParagraphStyle()
        para.alignment = .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 44, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: para
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let drawRect = panel.insetBy(dx: 34, dy: 34)
        UIGraphicsPushContext(ctx)
        attributed.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        UIGraphicsPopContext()
    }

    private func loadReferenceImage(for scene: LessonVideoScenePlan) async -> CGImage? {
        guard let raw = scene.referenceImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw)
        else {
            return nil
        }
        do {
            let data: Data
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                let (downloaded, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    return nil
                }
                data = downloaded
            }
            return UIImage(data: data)?.cgImage
        } catch {
            return nil
        }
    }

    private func aspectFitRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let imageAspect = imageSize.width / imageSize.height
        let targetAspect = bounds.width / bounds.height
        if imageAspect > targetAspect {
            let h = bounds.width / imageAspect
            return CGRect(x: bounds.minX, y: bounds.midY - (h / 2), width: bounds.width, height: h)
        }
        let w = bounds.height * imageAspect
        return CGRect(x: bounds.midX - (w / 2), y: bounds.minY, width: w, height: bounds.height)
    }

    private func drawDiagramOverlay(in panel: CGRect, context ctx: CGContext, progress: CGFloat, style: DiagramOverlayStyle) {
        let left = CGPoint(x: panel.minX + panel.width * 0.22, y: panel.midY)
        let right = CGPoint(x: panel.minX + panel.width * 0.78, y: panel.midY)
        let radius: CGFloat = 28

        ctx.setLineWidth(style == .pulse ? 6 : 4)
        let strokeColor = style == .pulse ? UIColor.systemPink.cgColor : UIColor.systemYellow.cgColor
        let fillColor = style == .pulse ? UIColor.systemTeal.withAlphaComponent(0.6).cgColor : UIColor.systemBlue.withAlphaComponent(0.55).cgColor
        ctx.setStrokeColor(strokeColor)
        ctx.setFillColor(fillColor)
        ctx.fillEllipse(in: CGRect(x: left.x - radius, y: left.y - radius, width: radius * 2, height: radius * 2))
        ctx.fillEllipse(in: CGRect(x: right.x - radius, y: right.y - radius, width: radius * 2, height: radius * 2))
        ctx.strokeEllipse(in: CGRect(x: left.x - radius, y: left.y - radius, width: radius * 2, height: radius * 2))
        ctx.strokeEllipse(in: CGRect(x: right.x - radius, y: right.y - radius, width: radius * 2, height: radius * 2))

        let animatedMidX = left.x + (right.x - left.x) * progress
        ctx.move(to: left)
        ctx.addLine(to: CGPoint(x: animatedMidX, y: left.y))
        ctx.strokePath()

        ctx.setFillColor(strokeColor)
        let arrow = UIBezierPath()
        arrow.move(to: CGPoint(x: animatedMidX, y: left.y))
        arrow.addLine(to: CGPoint(x: animatedMidX - 12, y: left.y - 8))
        arrow.addLine(to: CGPoint(x: animatedMidX - 12, y: left.y + 8))
        arrow.close()
        ctx.addPath(arrow.cgPath)
        ctx.fillPath()
    }
}

