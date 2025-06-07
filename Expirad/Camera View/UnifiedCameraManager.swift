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
    
    // MARK: - Private Properties
    private var session: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var ocrFrameCount = 0
    private var detectionConfidenceCount = 0
    private let requiredConfidenceFrames = 3 // Require 3 consistent detections
    
    // MARK: - Text-to-Speech for Accessibility
    private let speechSynthesizer = AVSpeechSynthesizer()
    @Published var isVoiceGuidanceEnabled = true
    private var hasSpokenInitialInstructions = false
    private var lastGuidanceTime: Date = Date()
    private var lastDetectedText: [String] = []
    
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
        updateUIForMode()
    }
    
    private func updateUIForMode() {
        if isPreview {
            statusMessage = "🔍 PREVIEW MODE"
            descriptionMessage = "Preview Display\nRun app for real camera"
            isCameraActive = false
        } else {
            statusMessage = "📷 CAMERA READY"
            descriptionMessage = "OCR Processing Running\nPoint at expiration date"
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
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        DispatchQueue.main.async {
            self.debugInfo = "Setting up camera session..."
        }
        
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
                self.positioningGuidance = "Hold steady, looking for expiration dates..."
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
    
    // MARK: - Voice Guidance System
    private func speakInitialInstructions() {
        let message = "Expirad is ready. Point your camera at a medicine package expiration date. I will guide you to the best position."
        speakGuidance(message)
        hasSpokenInitialInstructions = true
    }
    
    func speakGuidance(_ message: String, priority: Bool = false) {
        guard isVoiceGuidanceEnabled else { return }
        
        // Prevent too frequent speech
        let now = Date()
        if now.timeIntervalSince(lastGuidanceTime) < 2.0 && !priority {
            return
        }
        lastGuidanceTime = now
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 0.8
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension UnifiedCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Throttle OCR processing to every 10th frame for performance
        ocrFrameCount += 1
        guard ocrFrameCount % 10 == 0 else { return }
        
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
            }
            return
        }
        
        // Update OCR status
        DispatchQueue.main.async {
            self.ocrStatus = "Found \(detectedText.count) text elements"
            self.positioningGuidance = "Scanning for expiration dates..."
        }
        
        // Try to parse expiration date
        if let parsedDate = EnhancedDateParser.parseExpirationDate(from: detectedText) {
            handleSuccessfulDateDetection(parsedDate, from: detectedText)
        } else {
            // Provide positioning guidance based on detected text
            providePositioningGuidance(detectedText)
        }
        
        lastDetectedText = detectedText
    }
    
    private func handleSuccessfulDateDetection(_ date: Date, from texts: [String]) {
        detectionConfidenceCount += 1
        
        DispatchQueue.main.async {
            self.ocrStatus = "Date found! Confidence: \(self.detectionConfidenceCount)/\(self.requiredConfidenceFrames)"
        }
        
        // Require multiple consistent detections for confidence
        if detectionConfidenceCount >= requiredConfidenceFrames {
            DispatchQueue.main.async {
                self.detectedDate = date
                self.statusMessage = "✅ DATE DETECTED"
                self.descriptionMessage = "Expiration date found!"
                self.positioningGuidance = "Date successfully detected!"
                self.shouldNavigateToResult = true
            }
            
            // Announce the found date
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            let dateString = formatter.string(from: date)
            speakGuidance("Expiration date detected: \(dateString)", priority: true)
            
            print("✅ Date detected with confidence: \(date)")
        }
    }
    
    private func providePositioningGuidance(_ detectedText: [String]) {
        // Reset confidence count if we lost the date
        detectionConfidenceCount = 0
        
        // Analyze detected text to provide guidance
        let allText = detectedText.joined(separator: " ").uppercased()
        
        DispatchQueue.main.async {
            if allText.contains("EXP") || allText.contains("EXPIRE") {
                self.positioningGuidance = "Expiration area found! Hold steady..."
                self.speakGuidance("Found expiration area, hold camera steady")
            } else if allText.count > 100 {
                self.positioningGuidance = "Too much text. Focus on expiration area"
                self.speakGuidance("Move camera to focus on expiration date area")
            } else if allText.count < 20 {
                self.positioningGuidance = "Move closer to see more text"
                self.speakGuidance("Move camera closer to the package")
            } else {
                self.positioningGuidance = "Looking for expiration date pattern..."
            }
        }
    }
} 