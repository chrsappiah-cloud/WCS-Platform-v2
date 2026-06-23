//
//  LessonVideoScenePlan+Structured.swift
//  WCS-Platform
//
//  Syncs legacy flat scene fields with Chapter 9 structured plans (content / motion / conditioning).
//

import Foundation

extension LessonVideoScenePlan {
    /// Fills `conditioning`, `motion`, and `content` from legacy fields when absent.
    mutating func ensureStructuredPlans(stylePreset: String = "educational") {
        let resolvedMotion = motion?.type ?? CameraMotion.inferred(fromShotType: shotType)
        if conditioning == nil {
            conditioning = SceneConditioning(
                textPrompt: visualPrompt,
                negativePrompt: nil,
                referenceImageURL: referenceImageURL,
                referenceVideoURL: nil,
                cameraMotion: resolvedMotion,
                stylePreset: stylePreset
            )
        }
        if motion == nil {
            motion = MotionPlan(
                type: conditioning?.cameraMotion ?? resolvedMotion,
                speed: 0.5,
                pathControlPoints: nil
            )
        }
        if content == nil {
            content = ContentPlan.inferred(
                narration: narrationText,
                visualPrompt: visualPrompt,
                onScreenText: onScreenText
            )
        }
        syncLegacyFieldsFromStructuredPlans()
    }

    /// Keeps flat `visualPrompt`, `referenceImageURL`, and `shotType` aligned with structured plans for older BFF paths.
    mutating func syncLegacyFieldsFromStructuredPlans() {
        if conditioning != nil || motion != nil || content != nil {
            visualPrompt = generationVisualPrompt()
        }
        if let motion, shotType == nil || shotType?.isEmpty == true {
            shotType = motion.type.rawValue
        }
        if let conditioning, referenceImageURL == nil {
            referenceImageURL = conditioning.referenceImageURL
        }
    }

    /// Prompt sent to video backends: merges content, conditioning, and motion hints.
    func generationVisualPrompt() -> String {
        var parts: [String] = []
        if let content, !content.environment.isEmpty {
            parts.append("Environment: \(content.environment)")
        }
        if let entities = content?.entities, !entities.isEmpty {
            parts.append("Subjects: \(entities.joined(separator: ", "))")
        }
        if let actions = content?.actions, !actions.isEmpty {
            parts.append("Actions: \(actions.joined(separator: ", "))")
        }
        let text = conditioning?.textPrompt.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = text.isEmpty ? visualPrompt : text
        if !base.isEmpty {
            parts.append(base)
        }
        if let motion {
            parts.append("Camera: \(motion.type.displayLabel), intensity \(String(format: "%.1f", motion.speed)).")
        }
        if let style = conditioning?.stylePreset, !style.isEmpty {
            parts.append("Style: \(style).")
        }
        let merged = parts.joined(separator: " ")
        return merged.isEmpty ? visualPrompt : merged
    }

    /// Image-sequence motion multiplier derived from `MotionPlan.speed` and camera type.
    func imageSequenceMotionMultiplier(baseIntensity: CGFloat) -> CGFloat {
        let plan = motion ?? MotionPlan(type: CameraMotion.inferred(fromShotType: shotType), speed: 0.5, pathControlPoints: nil)
        let speedFactor = CGFloat(min(1.0, max(0.2, plan.speed)))
        let cameraFactor: CGFloat = {
            switch plan.type {
            case .staticShot: return 0.85
            case .slowZoomIn, .slowZoomOut, .dollyIn, .dollyOut: return 1.0
            case .panLeft, .panRight: return 1.15
            }
        }()
        return baseIntensity * speedFactor * cameraFactor
    }
}

extension LessonVideoStoryboard {
    /// Normalizes every scene before network render or composition.
    mutating func ensureStructuredPlansForAllScenes(stylePreset: String = "educational") {
        for index in scenes.indices {
            scenes[index].ensureStructuredPlans(stylePreset: stylePreset)
        }
    }
}
