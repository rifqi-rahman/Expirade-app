//
//  ContentView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI
import AVFoundation
import Vision



struct ContentView: View {
    @StateObject private var cameraManager = SafeCameraManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top section with title and buttons
                VStack(spacing: 16) {
                    // Title
                    Text("Camera")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                    
                    // Buttons HStack
                    HStack {
                        // Flash button
                        Button(action: {
                            cameraManager.toggleFlashlight()
                        }) {
                            Image(systemName: cameraManager.isFlashlightOn ? "bolt.fill" : "bolt")
                                .foregroundColor(.white)
                                .font(.title2)
                                .frame(width: 60, height: 60)
                                .background(cameraManager.isFlashlightOn ? Color.yellow : Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Spacer()
                        
                        // Help button
                        Button(action: {
                            // Help action
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                                .frame(width: 60, height: 60)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                .background(Color.white)
                
                // Camera Feed Area
                ZStack {
                    if let previewLayer = cameraManager.previewLayer, cameraManager.isCameraActive {
                        // Show real camera preview
                        ZStack {
                            CameraPreview(previewLayer: previewLayer)
                            
                            // Overlay UI elements
                            VStack {
                                // Live indicators at top
                                HStack {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                        Text("LIVE")
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(20)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                        Text("OCR")
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(20)
                                }
                                .padding(.top, 16)
                                .padding(.horizontal, 16)
                                
                                Spacer()
                            }
                        }
                    } else {
                        // Placeholder while loading
                        Rectangle()
                            .fill(Color.black)
                            .overlay(
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Text("Loading Camera...")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            )
                    }
                    
                    // Overlay information with semi-transparent background
        VStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            Text(cameraManager.statusMessage)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .font(.title3)
                                .shadow(color: .black, radius: 2)
                            
                            Text(cameraManager.descriptionMessage)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .font(.body)
                                .shadow(color: .black, radius: 1)
                            
                            Text("💡 Flashlight: \(cameraManager.isFlashlightOn ? "ON" : "OFF")")
                                .foregroundColor(cameraManager.isFlashlightOn ? .yellow : .white.opacity(0.8))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .shadow(color: .black, radius: 1)
                            
                            // Debug information with dark background
                            VStack(spacing: 4) {
                                Text("Debug: \(cameraManager.debugInfo)")
                                    .foregroundColor(.green)
                                    .font(.caption2)
                                
                                Text("OCR: \(cameraManager.ocrStatus)")
                                    .foregroundColor(.cyan)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(Color.white)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                cameraManager.requestPermissionAndStartSession()
            }
            .onDisappear {
                cameraManager.stopSession()
                cameraManager.stopSpeaking()
            }
        }
    }
}

// MARK: - Safe Camera Manager
class SafeCameraManager: NSObject, ObservableObject {
    @Published var isFlashlightOn = false
    @Published var isCameraActive = false
    @Published var statusMessage = "🔍 INITIALIZING"
    @Published var descriptionMessage = "Setting up camera..."
    @Published var debugInfo = "Starting..."
    @Published var ocrStatus = "No text detected yet"
    private var ocrFrameCount = 0
    
    private var session: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Text-to-Speech for Accessibility
    private let speechSynthesizer = AVSpeechSynthesizer()
    @Published var isVoiceGuidanceEnabled = true
    private var hasSpokenInitialInstructions = false
    private var lastGuidanceTime: Date = Date()
    
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    override init() {
        super.init()
        updateUIForMode()
    }
    
    private func updateUIForMode() {
        if isPreview {
            statusMessage = "🔍 PREVIEW MODE"
            descriptionMessage = "Preview Display\nRun app for real camera"
            isCameraActive = false
        } else {
            statusMessage = "📷 CAMERA READY"
            descriptionMessage = "Point at expiration date\nOCR processing active"
            isCameraActive = true
        }
    }
    
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
        
        // Speak initial accessibility instructions
        if isVoiceGuidanceEnabled && !hasSpokenInitialInstructions {
            speakInitialInstructions()
        }
        
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
        DispatchQueue.main.async {
            self.debugInfo = "Setting up camera session..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("🔧 Starting camera setup...")
            
            // Create session
            let session = AVCaptureSession()
            session.sessionPreset = .photo
            
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
                
                // Store references
                self.session = session
                self.captureDevice = camera
                
                DispatchQueue.main.async {
                    self.debugInfo = "Creating preview layer..."
                    
                    // Create preview layer
                    let preview = AVCaptureVideoPreviewLayer(session: session)
                    preview.videoGravity = .resizeAspectFill
                    self.previewLayer = preview
                }
                
                DispatchQueue.main.async {
                    self.debugInfo = "Starting camera session..."
                }
                
                // Start session
                session.startRunning()
                print("✅ Camera session started successfully")
                
                DispatchQueue.main.async {
                    self.statusMessage = "📷 CAMERA ACTIVE"
                    self.descriptionMessage = "OCR Processing Running\nPoint at expiration date"
                    self.debugInfo = "Camera running, OCR active"
                    self.isCameraActive = true
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
    }
    
    func stopSession() {
        guard !isPreview else { return }
        
        session?.stopRunning()
        print("⏹️ Camera session stopped")
    }
    
    func toggleFlashlight() {
        guard !isPreview else {
            // Simulate in preview
            isFlashlightOn.toggle()
            print("💡 Simulated flashlight: \(isFlashlightOn ? "ON" : "OFF")")
            return
        }
        
        guard let device = captureDevice, device.hasTorch else {
            print("❌ Flashlight not available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
                isFlashlightOn = true
            } else {
                device.torchMode = .off
                isFlashlightOn = false
            }
            
            device.unlockForConfiguration()
            print("💡 Flashlight: \(isFlashlightOn ? "ON" : "OFF")")
            
        } catch {
            print("❌ Flashlight error: \(error)")
        }
    }
    
    // MARK: - Voice Guidance for Accessibility
    
    private func speakInitialInstructions() {
        guard isVoiceGuidanceEnabled && !isPreview else { return }
        
        let instructions = "Welcome to Expirad. I'll help guide you to find expiration dates. Hold your phone steady and point the camera at your medicine package. I'll tell you when I detect text and help you position the camera correctly."
        
        speak(text: instructions)
        hasSpokenInitialInstructions = true
        
        // After initial instructions, give positioning guidance
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.speakPositioningGuidance()
        }
    }
    
    private func speakPositioningGuidance() {
        guard isVoiceGuidanceEnabled && !isPreview else { return }
        
        let guidance = "Now, slowly move your camera around the package. I'm looking for numbers that might be expiration dates. Keep the package about 6 inches away from your camera."
        
        speak(text: guidance)
    }
    
    private func speak(text: String) {
        guard isVoiceGuidanceEnabled && !speechSynthesizer.isSpeaking else { return }
        
        print("🔊 Speaking: \(text)")
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8 // Slightly slower for accessibility
        utterance.volume = 0.8
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    func toggleVoiceGuidance() {
        isVoiceGuidanceEnabled.toggle()
        if !isVoiceGuidanceEnabled {
            stopSpeaking()
        }
        print("🔊 Voice guidance: \(isVoiceGuidanceEnabled ? "ON" : "OFF")")
    }
    
    // MARK: - OCR Voice Guidance
    
    private func provideNoTextGuidance() {
        guard isVoiceGuidanceEnabled else { return }
        
        // Only provide guidance every 10 seconds to avoid overwhelming the user
        let now = Date()
        guard now.timeIntervalSince(lastGuidanceTime) > 10.0 else { return }
        lastGuidanceTime = now
        
        let guidance = "I don't see any expiration dates yet. Try moving your camera closer to the package, or look for words like 'EXP', 'Best Before', or 'Use By' on the label."
        speak(text: guidance)
    }
    
    private func announceTextDetection(textCount: Int) {
        guard isVoiceGuidanceEnabled else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastGuidanceTime) > 3.0 else { return }
        lastGuidanceTime = now
        
        let message = "I found \(textCount) piece\(textCount == 1 ? "" : "s") of text. Scanning for expiration date patterns like dates and keywords..."
        speak(text: message)
    }
    
    private func announceFoundDate(text: String, date: Date) {
        guard isVoiceGuidanceEnabled else { return }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let formattedDate = formatter.string(from: date)
        
        let message = "Found expiration date! \(text). This expires on \(formattedDate). Hold steady for a moment."
        speak(text: message)
    }
    
    private func provideTextButNoDateGuidance(observations: [VNRecognizedTextObservation]) {
        guard isVoiceGuidanceEnabled else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastGuidanceTime) > 8.0 else { return }
        lastGuidanceTime = now
        
        // Analyze text positions to provide directional guidance
        if let guidance = analyzeTextPositionForGuidance(observations: observations) {
            speak(text: guidance)
        } else {
            let message = "I see text but no expiration dates yet. Try moving the camera to different parts of the package to find the expiration date."
            speak(text: message)
        }
    }
    
    private func analyzeTextPositionForGuidance(observations: [VNRecognizedTextObservation]) -> String? {
        guard !observations.isEmpty else { return nil }
        
        // Calculate average position of detected text
        let avgX = observations.map { $0.boundingBox.midX }.reduce(0, +) / Double(observations.count)
        let avgY = observations.map { $0.boundingBox.midY }.reduce(0, +) / Double(observations.count)
        
        // Vision coordinates: (0,0) is bottom-left, but we want camera-relative directions
        // Convert to camera view coordinates where (0,0) is top-left
        let cameraY = 1.0 - avgY
        
        var guidance: [String] = []
        
        // Horizontal guidance
        if avgX < 0.3 {
            guidance.append("move right")
        } else if avgX > 0.7 {
            guidance.append("move left")
        }
        
        // Vertical guidance  
        if cameraY < 0.3 {
            guidance.append("move down")
        } else if cameraY > 0.7 {
            guidance.append("move up")
        }
        
        if !guidance.isEmpty {
            return "Try to \(guidance.joined(separator: " and ")) to center the text better."
        }
        
        return nil
    }
}

// MARK: - OCR Processing
extension SafeCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isCameraActive, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Increment frame counter
        ocrFrameCount += 1
        
        // Only process every 30th frame for performance (about once per second at 30fps)
        guard ocrFrameCount % 30 == 0 else { return }
        
        DispatchQueue.main.async {
            self.debugInfo = "Processing frame \(self.ocrFrameCount)"
        }
        
        // Perform OCR
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleOCRResults(request: request, error: error)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en"]
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        do {
            try handler.perform([request])
        } catch {
            print("❌ OCR processing error: \(error)")
            DispatchQueue.main.async {
                self.ocrStatus = "OCR processing error"
            }
        }
    }
    
    private func handleOCRResults(request: VNRequest, error: Error?) {
        if let error = error {
            print("❌ OCR Error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.ocrStatus = "OCR Error: \(error.localizedDescription)"
            }
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            DispatchQueue.main.async {
                self.ocrStatus = "No OCR results"
            }
            return
        }
        
        let detectedTexts = observations.compactMap { $0.topCandidates(1).first?.string }
        
        if detectedTexts.isEmpty {
            DispatchQueue.main.async {
                self.ocrStatus = "No text detected"
            }
            
            // Provide guidance when no text is found
            provideNoTextGuidance()
        } else {
            let textPreview = detectedTexts.prefix(3).joined(separator: ", ")
            DispatchQueue.main.async {
                self.ocrStatus = "Found: \(textPreview)"
            }
            
            print("🔍 OCR Detected \(detectedTexts.count) texts: \(detectedTexts)")
            
            // Provide voice feedback about text detection
            announceTextDetection(textCount: detectedTexts.count)
            
            // Look for expiration date patterns
            for text in detectedTexts {
                if let dateResult = findExpirationDate(in: text) {
                    print("📅 Found expiration date: \(dateResult.date)")
                    DispatchQueue.main.async {
                        self.ocrStatus = "FOUND DATE: \(dateResult.originalText) -> \(dateResult.date)"
                    }
                    
                    // Announce found expiration date
                    announceFoundDate(text: dateResult.originalText, date: dateResult.date)
                    return
                }
            }
            
            // If we have text but no dates, provide guidance
            provideTextButNoDateGuidance(observations: observations)
        }
    }
    
    // MARK: - Comprehensive Expiration Date Detection
    
    struct ExpirationDateResult {
        let date: Date
        let originalText: String
        let confidence: Float
    }
    
    private func findExpirationDate(in text: String) -> ExpirationDateResult? {
        let cleanText = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check all expiration date patterns
        let patterns = getExpirationDatePatterns()
        
        for pattern in patterns {
            if let match = cleanText.range(of: pattern.regex, options: .regularExpression) {
                let matchedText = String(cleanText[match])
                
                if let date = parseExpirationDate(matchedText, format: pattern.format) {
                    return ExpirationDateResult(
                        date: date,
                        originalText: matchedText,
                        confidence: pattern.confidence
                    )
                }
            }
        }
        
        return nil
    }
    
    private struct ExpirationPattern {
        let regex: String
        let format: ExpirationFormat
        let confidence: Float
    }
    
    private enum ExpirationFormat {
        case ddMMyy, ddMMyyyy, MMddyyyy, yyyyMMdd
        case ddMMMyy, ddMMMyyyy, MMMddyyyy
        case ddMMyy_spaced, ddMMyyyy_spaced
        case ddMMyy_dots, ddMMyyyy_dots, yyyyMM_dots
        case compact_ddMMyy, compact_yyyyMMdd, compact_MMMyy
        case monthYear, custom
    }
    
    private func getExpirationDatePatterns() -> [ExpirationPattern] {
        return [
            // Keywords with dates - High confidence
            ExpirationPattern(regex: #"(?:BEST BEFORE|EXP\.?:?|USE BY|BB:?|BBD:?|ED|BEST BY|E:?)\s*(\d{1,2}[\/\.\s]\d{1,2}[\/\.\s]\d{2,4})"#, format: .ddMMyyyy, confidence: 0.9),
            
            // Indonesian keywords
            ExpirationPattern(regex: #"(?:BAIK DIGUNAKAN SEBELUM|KODE PRODUKSI)\s*(\d{1,2}[\/\.\s]\d{1,2}[\/\.\s]\d{2,4})"#, format: .ddMMyyyy, confidence: 0.9),
            
            // Standard date formats - DD/MM/YYYY, DD.MM.YYYY
            ExpirationPattern(regex: #"\b(\d{1,2}[\/\.]\d{1,2}[\/\.]\d{4})\b"#, format: .ddMMyyyy, confidence: 0.8),
            
            // DD/MM/YY, DD.MM.YY
            ExpirationPattern(regex: #"\b(\d{1,2}[\/\.]\d{1,2}[\/\.]\d{2})\b"#, format: .ddMMyy, confidence: 0.7),
            
            // Spaced formats - DD MM YY, DD MM YYYY
            ExpirationPattern(regex: #"\b(\d{1,2}\s+\d{1,2}\s+\d{2,4})\b"#, format: .ddMMyyyy_spaced, confidence: 0.8),
            
            // YYYY.MM format
            ExpirationPattern(regex: #"\b(\d{4}\.\d{1,2})\b"#, format: .yyyyMM_dots, confidence: 0.7),
            
            // Month names - JUN25, JAN1027, etc.
            ExpirationPattern(regex: #"\b(\d{1,2}\s*(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s*\d{2,4})\b"#, format: .ddMMMyyyy, confidence: 0.8),
            
            // Compact formats - 140625, 221125, 120226
            ExpirationPattern(regex: #"\b(\d{6})\b"#, format: .compact_ddMMyy, confidence: 0.6),
            
            // Month-year only - 01 2026, FEB 2026
            ExpirationPattern(regex: #"\b(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC|0[1-9]|1[0-2])\s*(\d{4})\b"#, format: .monthYear, confidence: 0.5),
            
            // YYYY.MM.DD format
            ExpirationPattern(regex: #"\b(\d{4}\.\d{1,2}\.\d{1,2})\b"#, format: .yyyyMMdd, confidence: 0.8)
        ]
    }
    
    private func parseExpirationDate(_ text: String, format: ExpirationFormat) -> Date? {
        let cleanText = text.replacingOccurrences(of: #"[^\w\d\/\.\s]"#, with: "", options: .regularExpression)
        
        switch format {
        case .ddMMyyyy, .ddMMyy:
            return parseDDMMYYYY(cleanText)
            
        case .ddMMyyyy_spaced, .ddMMyy_spaced:
            return parseSpacedDate(cleanText)
            
        case .ddMMyyyy_dots, .ddMMyy_dots:
            return parseDottedDate(cleanText)
            
        case .yyyyMM_dots:
            return parseYYYYMM(cleanText)
            
        case .ddMMMyyyy, .ddMMMyy:
            return parseMonthNameDate(cleanText)
            
        case .compact_ddMMyy:
            return parseCompactDate(cleanText)
            
        case .monthYear:
            return parseMonthYear(cleanText)
            
        case .yyyyMMdd:
            return parseYYYYMMDD(cleanText)
            
        default:
            return nil
        }
    }
    
    // Helper parsing functions
    private func parseDDMMYYYY(_ text: String) -> Date? {
        let components = text.components(separatedBy: CharacterSet(charactersIn: "/.-"))
        guard components.count >= 2 else { return nil }
        
        let day = Int(components[0]) ?? 1
        let month = Int(components[1]) ?? 1
        let year = components.count > 2 ? Int(components[2]) ?? currentYear() : currentYear()
        
        return createDate(day: day, month: month, year: adjustYear(year))
    }
    
    private func parseSpacedDate(_ text: String) -> Date? {
        let components = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard components.count >= 2 else { return nil }
        
        let day = Int(components[0]) ?? 1
        let month = Int(components[1]) ?? 1
        let year = components.count > 2 ? Int(components[2]) ?? currentYear() : currentYear()
        
        return createDate(day: day, month: month, year: adjustYear(year))
    }
    
    private func parseDottedDate(_ text: String) -> Date? {
        let components = text.components(separatedBy: ".")
        guard components.count >= 2 else { return nil }
        
        let day = Int(components[0]) ?? 1
        let month = Int(components[1]) ?? 1
        let year = components.count > 2 ? Int(components[2]) ?? currentYear() : currentYear()
        
        return createDate(day: day, month: month, year: adjustYear(year))
    }
    
    private func parseYYYYMM(_ text: String) -> Date? {
        let components = text.components(separatedBy: ".")
        guard components.count >= 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else { return nil }
        
        return createDate(day: 1, month: month, year: year)
    }
    
    private func parseMonthNameDate(_ text: String) -> Date? {
        let monthMap: [String: Int] = [
            "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
            "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12
        ]
        
        let parts = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }
        
        var day = 1, month = 1, year = currentYear()
        
        for part in parts {
            if let monthNum = monthMap[part] {
                month = monthNum
            } else if let dayNum = Int(part), dayNum <= 31 {
                day = dayNum
            } else if let yearNum = Int(part) {
                year = adjustYear(yearNum)
            }
        }
        
        return createDate(day: day, month: month, year: year)
    }
    
    private func parseCompactDate(_ text: String) -> Date? {
        guard text.count == 6,
              let num = Int(text) else { return nil }
        
        // Try DDMMYY format first
        let day = num / 10000
        let month = (num % 10000) / 100
        let year = num % 100
        
        if isValidDate(day: day, month: month, year: adjustYear(year)) {
            return createDate(day: day, month: month, year: adjustYear(year))
        }
        
        // Try YYMMDD format
        let year2 = num / 10000
        let month2 = (num % 10000) / 100
        let day2 = num % 100
        
        if isValidDate(day: day2, month: month2, year: adjustYear(year2)) {
            return createDate(day: day2, month: month2, year: adjustYear(year2))
        }
        
        return nil
    }
    
    private func parseMonthYear(_ text: String) -> Date? {
        guard let year = Int(text) else { return nil }
        return createDate(day: 1, month: 1, year: year)
    }
    
    private func parseYYYYMMDD(_ text: String) -> Date? {
        let components = text.components(separatedBy: ".")
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]) else { return nil }
        
        return createDate(day: day, month: month, year: year)
    }
    
    // Helper functions
    private func currentYear() -> Int {
        return Calendar.current.component(.year, from: Date())
    }
    
    private func adjustYear(_ year: Int) -> Int {
        if year < 100 {
            // Convert 2-digit year to 4-digit
            return year < 50 ? 2000 + year : 1900 + year
        }
        return year
    }
    
    private func isValidDate(day: Int, month: Int, year: Int) -> Bool {
        return day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 2020 && year <= 2050
    }
    
    private func createDate(day: Int, month: Int, year: Int) -> Date? {
        guard isValidDate(day: day, month: month, year: year) else { return nil }
        
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        
        return Calendar.current.date(from: components)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
    ContentView()
    }
}
