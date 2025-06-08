//
//  UnifiedCameraManager.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI
import AVFoundation
import Vision
import Foundation
import CoreHaptics

// MARK: - Unified Camera Manager with Enhanced OCR
class UnifiedCameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isFlashlightOn = false
    @Published var isCameraActive = false
    @Published var statusMessage = "🔍 INITIALIZING"
    @Published var descriptionMessage = "Setting up camera..."
    @Published var debugInfo = "Starting..."
    @Published var ocrStatus = "No text detected yet"
    @Published var detectedDate: Date?
    @Published var shouldNavigateToResult = false
        @Published var positioningGuidance = "Hold steady, scanning for text..."
    @Published var previewRefreshID = UUID() // Force SwiftUI to refresh preview layer
    @Published var accessibilityStatus = "Scanning..." // Simple status for VoiceOver users
    
    // MARK: - Camera Control Methods
    func resetForNewScan() {
        detectedDate = nil
        shouldNavigateToResult = false
        detectionConfidenceCount = 0
        lastDetectedDate = nil
        hasSpokenInitialInstructions = false // Allow TTS guidance again
        
        // Re-enable OCR processing and unlock detection
        isOCRProcessingEnabled = true
        isDetectionInProgress = false // Unlock for new detection session
        
        // Force SwiftUI to refresh the preview layer by changing its ID
        previewRefreshID = UUID()
        
        // Update UI - camera session should still be running
        DispatchQueue.main.async {
            self.statusMessage = "📷 CAMERA ACTIVE"
            self.descriptionMessage = "OCR Processing Running\nPoint at expiration date"
            self.debugInfo = "Camera running, OCR active"
            self.isCameraActive = true
            self.positioningGuidance = "Ready! Point camera at medicine package"
            self.ocrStatus = "Looking for dates..."
            self.accessibilityStatus = "Ready to scan new package"
            
            // Restart TTS guidance for new scan
            if self.isVoiceGuidanceEnabled {
                self.speakInitialInstructions()
            }
        }
        
        print("✅ OCR processing re-enabled for new scan")
    }
    
    // MARK: - Private Properties
    private var session: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var ocrFrameCount = 0
    private var detectionConfidenceCount = 0
    private let requiredConfidenceFrames = 1 // Reduce to 1 for faster detection
    private var lastDetectedDate: Date?
    private var isOCRProcessingEnabled = true // Control OCR processing without stopping session
    private var isDetectionInProgress = false // Prevent multiple simultaneous detections
    
    // MARK: - Text-to-Speech for Accessibility
    private let speechSynthesizer = AVSpeechSynthesizer()
    @Published var isVoiceGuidanceEnabled = true
    private var hasSpokenInitialInstructions = false
    private var lastGuidanceTime: Date = Date()
    private var lastDetectedText: [String] = []
    
    // MARK: - Haptic Feedback for Success Detection
    private var hapticEngine: CHHapticEngine?
    
    // MARK: - Vision OCR
    private lazy var textRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleDetectedText(request: request, error: error)
        }
        
        // Enhanced OCR configuration for medicine packages
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.revision = VNRecognizeTextRequestRevision3
        
        return request
    }()
    
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupHapticEngine()
        updateUIForMode()
    }
    
    private func updateUIForMode() {
        if isPreview {
            statusMessage = "🔍 PREVIEW MODE"
            descriptionMessage = "Preview Display\nRun app for real camera"
            accessibilityStatus = "Preview mode"
            isCameraActive = false
            
            // Provide TTS feedback even in preview
            if isVoiceGuidanceEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.speakGuidance("Preview mode active. Build and run the app on a real device to use the camera and OCR features.", priority: true)
                }
            }
        } else {
            statusMessage = "📷 CAMERA READY"
            descriptionMessage = "OCR Processing Running\nPoint at expiration date"
            accessibilityStatus = "Ready to scan"
            isCameraActive = true
        }
    }
    
    // MARK: - Camera Setup and Control
    func requestPermissionAndStartSession() {
        guard !isPreview else {
            print("🔍 Preview mode detected - skipping camera setup")
            updateUIForMode()
            return
        }
        
        DispatchQueue.main.async {
            self.debugInfo = "Checking permissions..."
        }
        
        print("📱 Real device - setting up camera")
        
        // Don't speak here - will speak once camera is ready
        
        // Check camera permission
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("📹 Camera authorization status: \(authStatus.rawValue)")
        
        switch authStatus {
        case .authorized:
            DispatchQueue.main.async {
                self.debugInfo = "Permission granted, setting up..."
            }
            setupCamera()
        case .notDetermined:
            DispatchQueue.main.async {
                self.debugInfo = "Requesting permission..."
            }
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("📹 Camera access result: \(granted)")
                DispatchQueue.main.async {
                    if granted {
                        self?.debugInfo = "Permission granted!"
                        self?.setupCamera()
                    } else {
                        self?.statusMessage = "❌ CAMERA DENIED"
                        self?.descriptionMessage = "Enable camera in Settings"
                        self?.debugInfo = "Permission denied by user"
                        self?.isCameraActive = false
                    }
                }
            }
        case .denied:
            DispatchQueue.main.async {
                self.statusMessage = "❌ CAMERA DENIED"
                self.descriptionMessage = "Go to Settings > Expirad > Camera"
                self.debugInfo = "Camera permission denied"
                self.isCameraActive = false
                self.speakGuidance("Camera permission denied. Please go to Settings, then Expirad, then Camera, and enable camera access.", priority: true)
            }
        case .restricted:
            DispatchQueue.main.async {
                self.statusMessage = "❌ CAMERA RESTRICTED"
                self.descriptionMessage = "Camera access restricted"
                self.debugInfo = "Camera access restricted"
                self.isCameraActive = false
            }
        @unknown default:
            DispatchQueue.main.async {
                self.statusMessage = "❌ CAMERA UNAVAILABLE"
                self.descriptionMessage = "Unknown camera status"
                self.debugInfo = "Unknown permission status"
                self.isCameraActive = false
            }
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        DispatchQueue.main.async {
            self.debugInfo = "Setting up camera session..."
            self.statusMessage = "📷 INITIALIZING"
            self.descriptionMessage = "Camera starting..."
        }
        
        print("🔧 Starting camera setup...")
        
        // Create session
        let session = AVCaptureSession()
        session.sessionPreset = .high  // Use high quality for better OCR
        
        DispatchQueue.main.async {
            self.debugInfo = "Looking for camera device..."
        }
        
        // Get camera
        let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        let anyCamera = AVCaptureDevice.default(for: .video)
        
        guard let camera = backCamera ?? anyCamera else {
            print("❌ No camera device found")
            DispatchQueue.main.async {
                self.statusMessage = "❌ NO CAMERA"
                self.descriptionMessage = "Camera not available"
                self.debugInfo = "No camera device found"
                self.isCameraActive = false
            }
            return
        }
        
        print("✅ Found camera: \(camera.localizedName)")
        DispatchQueue.main.async {
            self.debugInfo = "Found: \(camera.localizedName)"
        }
        
        do {
            session.beginConfiguration()
            
            DispatchQueue.main.async {
                self.debugInfo = "Adding camera input..."
            }
            
            // Add camera input
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                print("✅ Camera input added")
            } else {
                print("❌ Cannot add camera input")
                DispatchQueue.main.async {
                    self.debugInfo = "Cannot add camera input"
                }
                return
            }
            
            DispatchQueue.main.async {
                self.debugInfo = "Setting up OCR output..."
            }
            
            // Set up OCR output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                print("✅ Video output added")
            } else {
                print("❌ Cannot add video output")
                DispatchQueue.main.async {
                    self.debugInfo = "Cannot add video output"
                }
                return
            }
            
            session.commitConfiguration()
            
            // Store references first
            self.session = session
            self.captureDevice = camera
            
            // Create preview layer immediately
            DispatchQueue.main.async {
                self.debugInfo = "Creating preview layer..."
                
                // Create preview layer
                let preview = AVCaptureVideoPreviewLayer(session: session)
                preview.videoGravity = .resizeAspectFill
                preview.connection?.videoRotationAngle = 90 // Portrait orientation equivalent
                self.previewLayer = preview
                
                print("✅ Preview layer created")
            }
            
            // Start session before updating UI
            DispatchQueue.main.async {
                self.debugInfo = "Starting camera session..."
                self.statusMessage = "📷 STARTING"
                self.descriptionMessage = "Camera loading..."
            }
            
            // Start session
            session.startRunning()
            print("✅ Camera session started successfully")
            
            // Give camera a moment to stabilize before declaring active
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if session.isRunning {
                    self.statusMessage = "📷 CAMERA ACTIVE"
                    self.descriptionMessage = "OCR Processing Running\nPoint at expiration date"
                    self.debugInfo = "Camera running, OCR active"
                    self.isCameraActive = true
                    self.positioningGuidance = "Ready! Point camera at medicine package"
                    
                    // Start TTS guidance once camera is fully ready
                    if self.isVoiceGuidanceEnabled && !self.hasSpokenInitialInstructions {
                        self.speakInitialInstructions()
                    }
                } else {
                    self.statusMessage = "❌ CAMERA FAILED"
                    self.descriptionMessage = "Camera failed to start"
                    self.debugInfo = "Session failed to start"
                    self.speakGuidance("Camera failed to start. Please restart the app.", priority: true)
                }
            }
            
        } catch {
            print("❌ Camera setup error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.statusMessage = "❌ CAMERA ERROR"
                self.descriptionMessage = "Setup failed: \(error.localizedDescription)"
                self.debugInfo = "Error: \(error.localizedDescription)"
                self.isCameraActive = false
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            guard let session = strongSelf.session else { return }
            if session.isRunning {
                session.stopRunning()
                print("⏹️ Camera session stopped")
            }
        }
    }
    
    // MARK: - Flashlight Controls
    func toggleFlashlight() {
        guard let device = captureDevice, device.hasTorch else {
            print("❌ Flashlight not available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
                DispatchQueue.main.async {
                    self.isFlashlightOn = true
                }
                print("💡 Flashlight ON")
                speakGuidance("Flashlight turned on")
            } else {
                device.torchMode = .off
                DispatchQueue.main.async {
                    self.isFlashlightOn = false
                }
                print("💡 Flashlight OFF")
                speakGuidance("Flashlight turned off")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("❌ Error toggling flashlight: \(error)")
        }
    }
    
    // MARK: - Direct Voice Guidance for Blind Users
    private func speakInitialInstructions() {
        guard isVoiceGuidanceEnabled else { return }
        
        // Direct, functional guidance
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.speakGuidance("Point camera at expiration date. Hold steady 6 inches away.", priority: true)
        }
        
        hasSpokenInitialInstructions = true
        print("🔊 Direct TTS guidance started")
    }
    
    func speakGuidance(_ message: String, priority: Bool = false) {
        guard isVoiceGuidanceEnabled else { 
            print("🔇 Voice guidance disabled")
            return 
        }
        
        // Prevent too frequent speech but allow priority messages
        let now = Date()
        if now.timeIntervalSince(lastGuidanceTime) < 1.5 && !priority {
            print("🔇 Speech throttled: \(message)")
            return
        }
        lastGuidanceTime = now
        
        print("🔊 Speaking: \(message)")
        
        // Stop any current speech before starting new one
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .word)
        }
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5  // Normal speed for better comprehension by blind users
        utterance.volume = 1.0  // Full volume for accessibility
        utterance.pitchMultiplier = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - Comprehensive Real-World Expiration Date Parser
    private func parseExpirationDateFast(from texts: [String]) -> Date? {
        // Prioritize texts with keywords
        let prioritizedTexts = texts.sorted { text1, text2 in
            let keywords = ["EXP", "EXPIRE", "BEST", "USE BY", "BB", "BBD", "ED", "E:", "B:", "KODE PRODUKSI", "BAIK DIGUNAKAN"]
            let hasKeyword1 = keywords.contains { text1.uppercased().contains($0) }
            let hasKeyword2 = keywords.contains { text2.uppercased().contains($0) }
            return hasKeyword1 && !hasKeyword2
        }
        
        for text in prioritizedTexts {
            let cleanText = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try all patterns in order of reliability
            if let date = parseKeywordBasedPatterns(cleanText) { return date }
            if let date = parseStandardDatePatterns(cleanText) { return date }
            if let date = parseCompactPatterns(cleanText) { return date }
            if let date = parseMonthNamePatterns(cleanText) { return date }
            if let date = parseSpecialFormats(cleanText) { return date }
        }
        
        return nil
    }
    
    // MARK: - Keyword-based patterns (highest confidence)
    private func parseKeywordBasedPatterns(_ text: String) -> Date? {
        let patterns = [
            // Standard keywords with various separators
            #"(?:EXP\.?:?\s*|EXPIRES?:?\s*|BEST\s+BEFORE:?\s*|USE\s+BY:?\s*|BB:?\s*|BBD:?\s*|ED:?\s*|E:?\s*|B:\s*)(\d{1,2}[\/\.\s]\d{1,2}[\/\.\s]\d{2,4})"#,
            // Compact after keywords: EXP 140625, EXP: 19032026
            #"(?:EXP\.?\s*:?\s*|E:?\s*)(\d{6,8})"#,
            // Month names after keywords: EXP 19 JUN25, EXP: 5 Jun 2026
            #"(?:EXP\.?\s*:?\s*|EXPIRES?:?\s*)(\d{1,2})\s*([A-Z]{3})\s*(\d{2,4})"#,
            // Keywords with month year: Best Before 02 2026
            #"(?:BEST\s+BEFORE|USE\s+BY)\s*(\d{1,2})\s+(\d{4})"#,
            // Indonesian patterns
            #"(?:KODE\s+PRODUKSI|BAIK\s+DIGUNAKAN\s+SEBELUM)\s*(\d{1,2}[\/\.\s]\d{1,2}[\/\.\s]\d{2,4})"#,
            // Special: EXP D format
            #"EXP\s+D\s+(\d{1,2}\.\d{1,2}\.\d{2,4})"#
        ]
        
        for pattern in patterns {
            if let date = parseWithRegexPattern(pattern, in: text) { return date }
        }
        return nil
    }
    
    // MARK: - Standard date patterns
    private func parseStandardDatePatterns(_ text: String) -> Date? {
        let patterns = [
            // DD/MM/YYYY, DD.MM.YYYY, DD-MM-YYYY
            #"(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})"#,
            // Spaced with dots: 03. 01. 26
            #"(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{2,4})"#,
            // Simple spaced: 20 01 25, 22 01 2026
            #"(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})"#,
            // Month year: 01 2026
            #"(\d{1,2})\s+(\d{4})"#,
            // YYYY.MM.DD and YYYY.MM
            #"(\d{4})\.(\d{1,2})(?:\.(\d{1,2}))?"#
        ]
        
        for pattern in patterns {
            if let date = parseWithRegexPattern(pattern, in: text) { return date }
        }
        return nil
    }
    
    // MARK: - Compact patterns
    private func parseCompactPatterns(_ text: String) -> Date? {
        let patterns = [
            // 6-digit: 140625, 221125, 120226
            #"\b(\d{6})\b"#,
            // 8-digit: 19032026
            #"\b(\d{8})\b"#
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let numStr = String(text[match])
                if let date = parseCompactNumber(numStr) { return date }
            }
        }
        return nil
    }
    
    // MARK: - Month name patterns
    private func parseMonthNamePatterns(_ text: String) -> Date? {
        let patterns = [
            // JAN1027, FEB2025
            #"([A-Z]{3})(\d{4})"#,
            // 30 DEC 25, 08 Dec 2025
            #"(\d{1,2})\s+([A-Z]{3})\s+(\d{2,4})"#,
            // DEC 25, APR 2026
            #"([A-Z]{3})\s+(\d{2,4})"#,
            // 06DEC25, 30NOV2025
            #"(\d{1,2})([A-Z]{3})(\d{2,4})"#,
            // EXP:12.FEB.2026
            #"(\d{1,2})\.([A-Z]{3})\.(\d{2,4})"#,
            // BEST BY AUG 01 2025
            #"([A-Z]{3})\s+(\d{1,2})\s+(\d{4})"#
        ]
        
        for pattern in patterns {
            if let date = parseMonthNameWithRegex(pattern, in: text) { return date }
        }
        return nil
    }
    
    // MARK: - Special formats
    private func parseSpecialFormats(_ text: String) -> Date? {
        // Handle mixed formats like "20001666 23.05.2025" - extract the date part
        let patterns = [
            #"\d+\s+(\d{1,2}\.\d{1,2}\.\d{4})"#,
            #"YYYY\.MM\.DD\s*(\d{4}\.\d{1,2}\.\d{1,2})"#
        ]
        
        for pattern in patterns {
            if let date = parseWithRegexPattern(pattern, in: text) { return date }
        }
        return nil
    }
    
    // MARK: - Helper parsing functions
    private func parseWithRegexPattern(_ pattern: String, in text: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            let components = (1..<match.numberOfRanges).compactMap { index -> String? in
                guard let range = Range(match.range(at: index), in: text) else { return nil }
                return String(text[range])
            }
            
            return parseFromComponents(components)
        }
        return nil
    }
    
    private func parseCompactNumber(_ numStr: String) -> Date? {
        if numStr.count == 6 {
            // DDMMYY: 140625, 221125
            let day = Int(numStr.prefix(2)) ?? 0
            let month = Int(numStr.dropFirst(2).prefix(2)) ?? 0  
            let yearSuffix = Int(numStr.suffix(2)) ?? 0
            let year = yearSuffix < 50 ? 2000 + yearSuffix : 1900 + yearSuffix
            
            if isValidDate(day: day, month: month, year: year) {
                return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
            }
        } else if numStr.count == 8 {
            // DDMMYYYY: 19032026
            let day = Int(numStr.prefix(2)) ?? 0
            let month = Int(numStr.dropFirst(2).prefix(2)) ?? 0
            let year = Int(numStr.suffix(4)) ?? 0
            
            if isValidDate(day: day, month: month, year: year) {
                return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
            }
        }
        return nil
    }
    
    private func parseMonthNameWithRegex(_ pattern: String, in text: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            let components = (1..<match.numberOfRanges).compactMap { index -> String? in
                guard let range = Range(match.range(at: index), in: text) else { return nil }
                return String(text[range])
            }
            
            return parseMonthNameComponents(components)
        }
        return nil
    }
    
    private func parseFromComponents(_ components: [String]) -> Date? {
        if components.count >= 3 {
            // DD/MM/YYYY format
            if let day = Int(components[0]), 
               let month = Int(components[1]),
               let year = parseYear(components[2]) {
                if isValidDate(day: day, month: month, year: year) {
                    return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
                }
            }
        } else if components.count == 2 {
            // MM YYYY format
            if let month = Int(components[0]), 
               let year = Int(components[1]) {
                if isValidDate(day: 1, month: month, year: year) {
                    return Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))
                }
            }
        }
        return nil
    }
    
    private func parseMonthNameComponents(_ components: [String]) -> Date? {
        let monthNames = ["JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
                         "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12]
        
        if components.count == 2 {
            // Month + Year: JAN1027, APR2026
            if let month = monthNames[components[0].uppercased()],
               let year = parseYear(components[1]) {
                return Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))
            }
        } else if components.count == 3 {
            // Day + Month + Year: 30 DEC 25, 08 Dec 2025
            if let day = Int(components[0]),
               let month = monthNames[components[1].uppercased()],
               let year = parseYear(components[2]) {
                if isValidDate(day: day, month: month, year: year) {
                    return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
                }
            }
            // Month + Day + Year: AUG 01 2025
            else if let month = monthNames[components[0].uppercased()],
                    let day = Int(components[1]),
                    let year = Int(components[2]) {
                if isValidDate(day: day, month: month, year: year) {
                    return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
                }
            }
        }
        return nil
    }
    
    private func parseYear(_ yearStr: String) -> Int? {
        guard let year = Int(yearStr) else { return nil }
        if year < 100 {
            return year < 50 ? 2000 + year : 1900 + year
        }
        return year
    }
    
    private func isValidDate(day: Int, month: Int, year: Int) -> Bool {
        guard month >= 1 && month <= 12 else { return false }
        guard day >= 1 && day <= 31 else { return false }
        guard year >= 1900 && year <= 2050 else { return false }
        
        // Quick validation for days per month
        let daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        let maxDay = month == 2 && isLeapYear(year) ? 29 : daysInMonth[month - 1]
        
        return day <= maxDay
    }
    
    private func isLeapYear(_ year: Int) -> Bool {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }
    
    // MARK: - Haptic Feedback System
    private func setupHapticEngine() {
        // Check if haptics are supported
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("🔇 Device doesn't support haptics")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            print("✅ Haptic engine initialized")
        } catch {
            print("❌ Failed to create haptic engine: \(error)")
        }
    }
    
    private func triggerSuccessHaptic() {
        guard let engine = hapticEngine else {
            print("🔇 Haptic engine not available")
            return
        }
        
        // Create a success pattern: two strong taps
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0, duration: 0.2),
            
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0.3, duration: 0.2)
        ]
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            print("🎯 Success haptic feedback triggered")
        } catch {
            print("❌ Failed to play haptic: \(error)")
        }
    }
    
    private func parseDDMMYYYYPattern(_ text: String) -> Date? {
        let pattern = #"(\d{1,2})[\/\.](\d{1,2})[\/\.](\d{2,4})"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let components = String(text[match]).components(separatedBy: CharacterSet(charactersIn: "/."))
            if components.count == 3,
               let day = Int(components[0]),
               let month = Int(components[1]),
               let year = Int(components[2]) {
                return createFastDate(day: day, month: month, year: adjustYearFast(year))
            }
        }
        return nil
    }
    
    private func parseSpacedPattern(_ text: String) -> Date? {
        let pattern = #"(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let components = String(text[match]).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count == 3,
               let day = Int(components[0]),
               let month = Int(components[1]),
               let year = Int(components[2]) {
                return createFastDate(day: day, month: month, year: adjustYearFast(year))
            }
        }
        return nil
    }
    
    private func parseCompactPattern(_ text: String) -> Date? {
        let pattern = #"\b(\d{6})\b"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let numStr = String(text[match])
            if let num = Int(numStr) {
                let day = num / 10000
                let month = (num % 10000) / 100
                let year = num % 100
                return createFastDate(day: day, month: month, year: adjustYearFast(year))
            }
        }
        return nil
    }
    
    private func parseMonthNamePattern(_ text: String) -> Date? {
        let monthMap: [String: Int] = [
            "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
            "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12
        ]
        
        let pattern = #"(\d{1,2})?\s*([A-Z]{3})\s*(\d{2,4})"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let components = String(text[match]).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 {
                var day = 1
                var month = 1
                var year = 2025
                
                for component in components {
                    if let monthNum = monthMap[component] {
                        month = monthNum
                    } else if let dayNum = Int(component), dayNum <= 31 {
                        if dayNum < 1000 {
                            day = dayNum
                        } else {
                            year = adjustYearFast(dayNum)
                        }
                    } else if let yearNum = Int(component) {
                        year = adjustYearFast(yearNum)
                    }
                }
                
                return createFastDate(day: day, month: month, year: year)
            }
        }
        return nil
    }
    
    private func parseYYYYMMPattern(_ text: String) -> Date? {
        let pattern = #"(\d{4})\.(\d{1,2})"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let components = String(text[match]).components(separatedBy: ".")
            if components.count == 2,
               let year = Int(components[0]),
               let month = Int(components[1]) {
                return createFastDate(day: 1, month: month, year: year)
            }
        }
        return nil
    }
    
    private func parseMMYYYYPattern(_ text: String) -> Date? {
        let pattern = #"(\d{1,2})\s+(\d{4})"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let components = String(text[match]).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count == 2,
               let month = Int(components[0]),
               let year = Int(components[1]),
               month >= 1 && month <= 12 {
                return createFastDate(day: 1, month: month, year: year)
            }
        }
        return nil
    }
    
    private func createFastDate(day: Int, month: Int, year: Int) -> Date? {
        guard day >= 1 && day <= 31 && 
              month >= 1 && month <= 12 && 
              year >= 2024 && year <= 2040 else { return nil }
        
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        return Calendar.current.date(from: components)
    }
    
    private func adjustYearFast(_ year: Int) -> Int {
        if year < 100 {
            return year < 50 ? 2000 + year : 1900 + year
        }
        return year
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension UnifiedCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Skip OCR processing if disabled (e.g., during navigation to ResultView)
        guard isOCRProcessingEnabled else { return }
        
        // Increase OCR processing frequency for faster detection
        ocrFrameCount += 1
        guard ocrFrameCount % 5 == 0 else { return } // Process every 5th frame instead of 10th
        
        // Convert sample buffer to CVPixelBuffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Perform text recognition on the frame
        performTextRecognition(on: pixelBuffer)
    }
    
    private func performTextRecognition(on pixelBuffer: CVPixelBuffer) {
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try imageRequestHandler.perform([textRequest])
        } catch {
            print("❌ Error performing text recognition: \(error.localizedDescription)")
        }
    }
    
    private func handleDetectedText(request: VNRequest, error: Error?) {
        if let error = error {
            print("❌ Text recognition error: \(error.localizedDescription)")
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        // Extract all detected text
        let detectedText = observations.compactMap { observation in
            return observation.topCandidates(1).first?.string
        }
        
        // Only process if we have detected text
        guard !detectedText.isEmpty else {
            DispatchQueue.main.async {
                self.ocrStatus = "Looking for text..."
                self.positioningGuidance = "Move camera closer to text"
                self.accessibilityStatus = "No text detected. Move closer."
            }
            return
        }
        
        // Quick pre-filter: only process if text contains numbers
        let hasNumbers = detectedText.contains { text in
            text.rangeOfCharacter(from: .decimalDigits) != nil
        }
        
        guard hasNumbers else {
            DispatchQueue.main.async {
                self.ocrStatus = "Looking for dates..."
                self.positioningGuidance = "Move to find numbers or dates"
                self.accessibilityStatus = "Text found. Looking for expiration date."
                
                // Provide occasional guidance when no numbers found
                if self.ocrFrameCount % 50 == 0 {  // Every ~10 seconds
                    self.speakGuidance("Point at expiration date area.", priority: false)
                    self.accessibilityStatus = "No date found. Try different angle."
                }
            }
            return
        }
        
        // Update OCR status
        DispatchQueue.main.async {
            self.ocrStatus = "Found \(detectedText.count) text elements"
            self.positioningGuidance = "Scanning for expiration dates..."
            self.accessibilityStatus = "Scanning text for expiration date..."
        }
        
        // Try to parse expiration date using inline fast parser
        if let parsedDate = parseExpirationDateFast(from: detectedText) {
            handleSuccessfulDateDetection(parsedDate, from: detectedText)
        } else {
            // Provide positioning guidance based on detected text
            providePositioningGuidance(detectedText)
        }
        
        lastDetectedText = detectedText
    }
    
    private func handleSuccessfulDateDetection(_ date: Date, from texts: [String]) {
        // CRITICAL: Prevent multiple simultaneous detections
        guard !isDetectionInProgress else {
            print("🔒 Detection already in progress, skipping duplicate")
            return
        }
        
        // Fast detection - check if it's the same date to avoid duplicates
        if let lastDate = lastDetectedDate, 
           Calendar.current.isDate(date, inSameDayAs: lastDate) {
            detectionConfidenceCount += 1
        } else {
            // New date detected, reset counter
            detectionConfidenceCount = 1
            lastDetectedDate = date
        }
        
        DispatchQueue.main.async {
            self.ocrStatus = "Date found! Confidence: \(self.detectionConfidenceCount)/\(self.requiredConfidenceFrames)"
        }
        
        // Immediate detection with just 1 confirmation for speed
        if detectionConfidenceCount >= requiredConfidenceFrames {
            // IMMEDIATELY lock further detections
            isDetectionInProgress = true
            
            DispatchQueue.main.async {
                self.detectedDate = date
                self.statusMessage = "✅ DATE DETECTED"
                self.descriptionMessage = "Expiration date found!"
                self.positioningGuidance = "Date successfully detected!"
                self.accessibilityStatus = "Expiration date detected!"
                self.shouldNavigateToResult = true
            }
            
            // Trigger haptic feedback for successful detection (ONCE)
            triggerSuccessHaptic()
            
            // Announce the found date immediately
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            let dateString = formatter.string(from: date)
            speakGuidance("Expiration date detected: \(dateString)", priority: true)
            
            print("✅ Date detected instantly: \(date) - Detection locked")
            
            // Disable OCR processing temporarily instead of stopping session
            self.isOCRProcessingEnabled = false
        }
    }
    
    private func providePositioningGuidance(_ detectedText: [String]) {
        // Reset confidence count if we lost the date
        detectionConfidenceCount = 0
        
        // Analyze detected text to provide guidance
        let allText = detectedText.joined(separator: " ").uppercased()
        
        DispatchQueue.main.async {
            if allText.contains("EXP") || allText.contains("EXPIRE") || allText.contains("BEST") || allText.contains("USE BY") {
                self.positioningGuidance = "Expiration area found! Hold steady..."
                self.speakGuidance("Found expiration area, hold steady.", priority: false)
            } else if allText.contains(where: { $0.isNumber }) {
                // Has numbers but no keywords
                self.positioningGuidance = "Found numbers, looking for dates..."
                self.speakGuidance("Scanning numbers for date.", priority: false)
            } else if allText.count > 100 {
                self.positioningGuidance = "Too much text. Focus on expiration area"
                self.speakGuidance("Move to expiration area.", priority: false)
            } else if allText.count < 10 {
                self.positioningGuidance = "Move closer to see more text"
                self.speakGuidance("Move closer.", priority: false)
            } else {
                self.positioningGuidance = "Scanning for expiration dates..."
                // Don't speak this one to avoid too much chatter
            }
        }
    }
} 