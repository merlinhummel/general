//
//  ProjectConfiguration.swift
//  Hammer Track
//
//  Configuration and Debug Settings
//

import Foundation
import AVFoundation

struct ProjectConfiguration {
    // Debug Settings
    static let enableDebugLogging = false
    static let enablePerformanceLogging = false
    static let frameProcessingInterval = 3 // Process every 3rd frame
    
    // Camera Settings
    static let preferredCameraPosition: AVCaptureDevice.Position = .back
    static let sessionPreset: AVCaptureSession.Preset = .hd1920x1080
    
    // Analysis Settings
    static let armRaisedThreshold: TimeInterval = 0.2
    static let maxFramesWithoutHammer = 7
    static let minConfidenceThreshold: Float = 0.75
    
    // UI Update Settings
    static let uiUpdateInterval: TimeInterval = 0.2 // Update UI every 200ms
    
    // Performance Settings
    static let enableFrameThrottling = true
    static let maxConcurrentProcessing = 2
}
