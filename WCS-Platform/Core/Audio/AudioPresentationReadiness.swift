//
//  AudioPresentationReadiness.swift
//  WCS-Platform
//

import AVFoundation
import AVFAudio
import Foundation

struct AudioPresentationReadiness: Hashable {
    let audioSystemStatus: String
    let microphoneChecklist: [String]

    static func snapshot() -> AudioPresentationReadiness {
        let session = AVAudioSession.sharedInstance()
        let inputAvailable = session.isInputAvailable
        let permission = AVAudioApplication.shared.recordPermission

        let permissionLabel: String
        switch permission {
        case .granted:
            permissionLabel = "granted"
        case .denied:
            permissionLabel = "denied"
        case .undetermined:
            permissionLabel = "undetermined"
        @unknown default:
            permissionLabel = "unknown"
        }

        let checklist = [
            "AVAudioSession available: yes",
            "Microphone input available: \(inputAvailable ? "yes" : "no")",
            "Record permission: \(permissionLabel)",
            "Recommendation: use /v1/audio/transcriptions to validate spoken presentation quality"
        ]

        let status = inputAvailable
            ? "Ready for module presentation recording"
            : "Playback-only mode; microphone currently unavailable"

        return AudioPresentationReadiness(
            audioSystemStatus: status,
            microphoneChecklist: checklist
        )
    }
}
