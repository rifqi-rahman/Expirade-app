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

// MARK: - Timing Configuration
private let CAMERA_TTS_CLEANUP_DELAY: Double = 0.8 // Time to allow Camera TTS to finish before stopping
// Adjust this value to control delay after successful scan:
// - 0.5 = Very fast (may cut off TTS)  
// - 0.8 = Balanced (current)
// - 1.5 = Safer but slower

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
    
    // --- Drug Name Detection Phase ---
    enum OCRPhase {
        case drugName
        case expirationDate
    }
    
    @Published var ocrPhase: OCRPhase = .drugName
    @Published var detectedDrugName: String? = nil
    @Published var showDrugNameAlert: Bool = false
    
    // MARK: - Camera Control Methods
    func resetForNewScan() {
        detectedDate = nil
        shouldNavigateToResult = false
        detectionConfidenceCount = 0
        lastDetectedDate = nil
        hasSpokenInitialInstructions = false // Allow TTS guidance again
        
        // Reset to drug name phase
        ocrPhase = .drugName
        detectedDrugName = nil
        showDrugNameAlert = false
        
        // IMPORTANT: Stop any lingering TTS and cancel pending delayed calls from previous session
        stopSpeaking()
        
        // Re-enable OCR processing and unlock detection
        isOCRProcessingEnabled = true
        isDetectionInProgress = false // Unlock for new detection session
        
        // Force SwiftUI to refresh the preview layer by changing its ID
        previewRefreshID = UUID()
        
        // Update UI - camera session should still be running
        DispatchQueue.main.async {
            self.statusMessage = "💊 SCANNING DRUG NAME"
            self.descriptionMessage = "OCR Processing Running\nPoint at drug name first"
            self.debugInfo = "Camera running, OCR active"
            self.isCameraActive = true
            self.positioningGuidance = "Ready! Point camera at drug name"
            self.ocrStatus = "Looking for drug names..."
            self.accessibilityStatus = "Siap memindai nama obat"
            
            // Restart TTS guidance for new scan
            if self.isVoiceGuidanceEnabled {
                self.speakInitialInstructions()
            }
        }
        
        print("✅ OCR processing re-enabled for new scan - Drug Name Phase")
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
    
    // MARK: - Cancellable TTS Management
    private var pendingTTSWorkItems: [DispatchWorkItem] = []
    
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
            accessibilityStatus = "Mode pratinjau"
            isCameraActive = false
            
            // Provide TTS feedback even in preview
            if isVoiceGuidanceEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.speakGuidance("Mode pratinjau aktif. Bangun dan jalankan aplikasi di perangkat asli untuk menggunakan kamera dan fitur OCR.", priority: true)
                }
            }
        } else {
            statusMessage = "💊 SCANNING DRUG NAME"
            descriptionMessage = "OCR Processing Running\nPoint at drug name first"
            accessibilityStatus = "Siap memindai nama obat"
            isCameraActive = true
            ocrPhase = .drugName // Ensure we start with drug name phase
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
                self.speakGuidance("Izin kamera ditolak. Silakan buka Pengaturan, lalu Expirad, lalu Kamera, dan aktifkan akses kamera.", priority: true)
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
                    self.statusMessage = "💊 SCANNING DRUG NAME"
                    self.descriptionMessage = "OCR Processing Running\nPoint at drug name first"
                    self.debugInfo = "Camera running, OCR active"
                    self.isCameraActive = true
                    self.positioningGuidance = "Ready! Point camera at drug name"
                    self.ocrPhase = .drugName // Ensure we start with drug name phase
                    
                    // Start TTS guidance once camera is fully ready
                    if self.isVoiceGuidanceEnabled && !self.hasSpokenInitialInstructions {
                        self.speakInitialInstructions()
                    }
                } else {
                    self.statusMessage = "❌ CAMERA FAILED"
                    self.descriptionMessage = "Camera failed to start"
                    self.debugInfo = "Session failed to start"
                    self.speakGuidance("Kamera gagal dimulai. Silakan mulai ulang aplikasi.", priority: true)
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
                speakGuidance("Senter dinyalakan")
            } else {
                device.torchMode = .off
                DispatchQueue.main.async {
                    self.isFlashlightOn = false
                }
                print("💡 Flashlight OFF")
                speakGuidance("Senter dimatikan")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("❌ Error toggling flashlight: \(error)")
        }
    }
    
    // MARK: - Comprehensive Indonesian Voice Guidance for Blind Users
    private func speakInitialInstructions() {
        guard isVoiceGuidanceEnabled else { return }
        
        // Cancel any existing pending TTS first
        cancelAllPendingTTS()
        
        // Schedule cancellable Indonesian guidance with timing for drug name phase
        if ocrPhase == .drugName {
            scheduleTTS(delay: 1.0, message: "Selamat datang. Arahkan kamera ke nama obat pada kemasan.")
            scheduleTTS(delay: 4.0, message: "Tahan kamera stabil sekitar 20 sentimeter dari kemasan.")
            scheduleTTS(delay: 7.5, message: "Cari area yang menampilkan nama obat. Ketuk dua kali untuk fokus.")
        } else {
            // Expiration date phase
            scheduleTTS(delay: 1.0, message: "Sekarang arahkan kamera ke tanggal kadaluarsa.")
            scheduleTTS(delay: 4.0, message: "Cari tulisan EXP, kadaluarsa, atau tanggal pada kemasan.")
            scheduleTTS(delay: 7.5, message: "Tahan kamera stabil sekitar 15 sentimeter dari area tanggal.")
        }
        
        hasSpokenInitialInstructions = true
        print("🔊 Scheduled 3 cancellable Indonesian TTS guidance messages for \(ocrPhase == .drugName ? "drug name" : "expiration date") phase")
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
        
        print("🔊 Speaking (Indonesian): \(message)")
        
        // Stop any current speech before starting new one
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .word)
        }
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5  // Slower for better Indonesian comprehension
        utterance.volume = 1.0  // Full volume for accessibility
        utterance.pitchMultiplier = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        cancelAllPendingTTS()
    }
    
    // MARK: - Cancellable TTS Management
    private func cancelAllPendingTTS() {
        // Cancel all pending delayed TTS calls
        let cancelledCount = pendingTTSWorkItems.count
        for workItem in pendingTTSWorkItems {
            workItem.cancel()
        }
        pendingTTSWorkItems.removeAll()
        if cancelledCount > 0 {
            print("🚫 Cancelled \(cancelledCount) pending TTS calls")
        }
    }
    
    private func scheduleTTS(delay: Double, message: String, priority: Bool = true) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.speakGuidance(message, priority: priority)
        }
        
        pendingTTSWorkItems.append(workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    // MARK: - Additional Indonesian Help Functions
    func speakDetailedHelp() {
        guard isVoiceGuidanceEnabled else { return }
        
        // Completely stop any current speech and cancel pending TTS
        stopSpeaking()
        
        if ocrPhase == .drugName {
            // Drug name phase guidance
            scheduleTTS(delay: 0.5, message: "Panduan lengkap Expirade - Fase Nama Obat:")
            scheduleTTS(delay: 3.0, message: "Pertama, pastikan kemasan obat dalam pencahayaan yang cukup.")
            scheduleTTS(delay: 6.0, message: "Kedua, cari area yang menampilkan nama obat pada kemasan.")
            scheduleTTS(delay: 9.0, message: "Ketiga, arahkan kamera tepat ke area nama obat tersebut.")
            scheduleTTS(delay: 12.0, message: "Tahan kamera stabil sekitar 15 sentimeter dari kemasan.")
            scheduleTTS(delay: 15.0, message: "Aplikasi akan menampilkan popup konfirmasi ketika nama obat terdeteksi.")
        } else {
            // Expiration date phase guidance
            scheduleTTS(delay: 0.5, message: "Panduan lengkap Expirade - Fase Tanggal Kadaluarsa:")
            scheduleTTS(delay: 3.0, message: "Pertama, pastikan kemasan obat dalam pencahayaan yang cukup.")
            scheduleTTS(delay: 6.0, message: "Kedua, cari tulisan EXP, kadaluarsa, atau tanggal pada kemasan.")
            scheduleTTS(delay: 9.0, message: "Ketiga, arahkan kamera tepat ke area tanggal tersebut.")
            scheduleTTS(delay: 12.0, message: "Tahan kamera stabil sekitar 15 sentimeter dari kemasan.")
            scheduleTTS(delay: 15.0, message: "Aplikasi akan memberikan getaran dan suara ketika tanggal terdeteksi.")
        }
        
        print("🔊 Scheduled 6 cancellable detailed help messages for \(ocrPhase == .drugName ? "drug name" : "expiration date") phase")
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
    
    // MARK: - Drug Name Confirmation Handler
    func userConfirmedDrugName(_ confirmed: Bool) {
        if confirmed {
            // User confirmed the drug name, move to expiration date phase
            ocrPhase = .expirationDate
            detectedDrugName = detectedDrugName // Keep the detected name
            
            DispatchQueue.main.async {
                self.statusMessage = "📅 SCANNING EXPIRATION"
                self.descriptionMessage = "Drug confirmed: \(self.detectedDrugName ?? "")\nNow scanning for expiration date"
                self.accessibilityStatus = "Nama obat dikonfirmasi. Sekarang memindai tanggal kadaluarsa"
                self.ocrStatus = "Looking for expiration date..."
                self.positioningGuidance = "Point camera at expiration date area"
            }
            
            // Resume OCR processing for expiration date detection
            resumeCameraAndOCR()
            
            // Provide guidance for expiration date scanning
            speakGuidance("Nama obat dikonfirmasi. Sekarang arahkan kamera ke area tanggal kadaluarsa", priority: true)
            
        } else {
            // User rejected the drug name, continue scanning for drug names
            detectedDrugName = nil
            showDrugNameAlert = false
            
            DispatchQueue.main.async {
                self.statusMessage = "💊 SCANNING DRUG NAME"
                self.descriptionMessage = "Looking for drug name on package"
                self.accessibilityStatus = "Memindai nama obat"
                self.ocrStatus = "Looking for drug names..."
                self.positioningGuidance = "Point camera at drug name area"
            }
            
            // Resume OCR processing for drug name detection
            resumeCameraAndOCR()
            
            // Provide guidance for drug name scanning
            speakGuidance("Mencari nama obat lain", priority: true)
        }
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
    
    // --- OCR Pipeline Modification ---
    private func handleDetectedText(request: VNRequest, error: Error?) {
        guard isOCRProcessingEnabled else { return }
        guard let results = request.results as? [VNRecognizedTextObservation] else { return }
        let detectedText = results.compactMap { $0.topCandidates(1).first?.string }
        if detectedText.isEmpty { return }

        // PHASE 1: Drug Name Detection
        if ocrPhase == .drugName {
            if let drugName = extractDrugName(from: detectedText) {
                DispatchQueue.main.async {
                    self.detectedDrugName = drugName
                    self.showDrugNameAlert = true
                }
                pauseCameraAndOCR()
                return
            }
            // Optionally: update accessibilityStatus for this phase
            DispatchQueue.main.async {
                self.accessibilityStatus = "Memindai nama obat..."
            }
            return
        }
        // PHASE 2: Expiration Date Detection (existing logic)
        DispatchQueue.main.async {
            self.accessibilityStatus = "Memindai teks untuk tanggal kadaluarsa..."
        }
        if let parsedDate = parseExpirationDateFast(from: detectedText) {
            handleSuccessfulDateDetection(parsedDate, from: detectedText)
        } else {
            providePositioningGuidance(detectedText)
        }
        lastDetectedText = detectedText
    }
    
    private func extractDrugName(from texts: [String]) -> String? {
        // Simple heuristic: first line that is not a date and not a keyword
        let keywords = ["EXP", "EXPIRE", "BEST", "USE BY", "BB", "BBD", "ED", "E:", "B:", "KODE PRODUKSI", "BAIK DIGUNAKAN"]
        for line in texts {
            let upper = line.uppercased()
            if keywords.contains(where: { upper.contains($0) }) { continue }
            if upper.range(of: #"\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{2,4}"#, options: .regularExpression) != nil { continue }
            if upper.range(of: #"\d{6,8}"#, options: .regularExpression) != nil { continue }
            if line.trimmingCharacters(in: .whitespaces).count > 2 {
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
    
    private func pauseCameraAndOCR() {
        isOCRProcessingEnabled = false
        isDetectionInProgress = true
    }
    
    private func resumeCameraAndOCR() {
        isOCRProcessingEnabled = true
        isDetectionInProgress = false
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
                self.accessibilityStatus = "Tanggal kadaluarsa terdeteksi!"
                self.shouldNavigateToResult = true
            }
            
            // Trigger haptic feedback for successful detection (ONCE)
            triggerSuccessHaptic()
            
            // CRITICAL: Stop any current TTS to prevent conflict with ResultView
            stopSpeaking()
            
            // Announce the found date with shorter message to prevent overlap
            speakGuidance("Tanggal terdeteksi", priority: true)
            
            print("✅ Date detected instantly: \(date) - Detection locked")
            
            // Disable OCR processing temporarily instead of stopping session
            self.isOCRProcessingEnabled = false
            
            // Stop TTS after a brief moment to ensure clean handoff to ResultView
            DispatchQueue.main.asyncAfter(deadline: .now() + CAMERA_TTS_CLEANUP_DELAY) {
                self.stopSpeaking()
            }
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
                self.speakGuidance("Mencari area kadaluarsa, tahan stabil.", priority: false)
            } else if allText.contains(where: { $0.isNumber }) {
                // Has numbers but no keywords
                self.positioningGuidance = "Found numbers, looking for dates..."
                self.speakGuidance("Memindai angka untuk tanggal.", priority: false)
            } else if allText.count > 100 {
                self.positioningGuidance = "Too much text. Focus on expiration area"
                self.speakGuidance("Pindah ke area kadaluarsa.", priority: false)
            } else if allText.count < 10 {
                self.positioningGuidance = "Move closer to see more text"
                self.speakGuidance("Gerakkan lebih dekat.", priority: false)
            } else {
                self.positioningGuidance = "Scanning for expiration dates..."
                // Don't speak this one to avoid too much chatter
            }
        }
    }
}
