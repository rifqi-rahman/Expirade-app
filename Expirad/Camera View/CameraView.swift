//
//  CameraView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI
import AVFoundation
import Vision
import Foundation

// MARK: - Camera Manager with OCR
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var captureDevice: AVCaptureDevice?
    
    // Navigation and date detection
    @Published var detectedDate: Date?
    @Published var shouldNavigateToResult = false
    @Published var isFlashlightOn = false
    
    // Vision text recognition request
    private lazy var textRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleDetectedText(request: request, error: error)
        }
        
        // Configure for optimal OCR performance
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        return request
    }()
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        
        // Set session preset
        session.sessionPreset = .photo
        
        // Get back camera
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ Unable to access back camera!")
            session.commitConfiguration()
            return
        }
        
        self.captureDevice = backCamera
        
        do {
            // Create camera input
            let cameraInput = try AVCaptureDeviceInput(device: backCamera)
            
            // Add camera input to session
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            }
            
            // Configure video output for OCR processing
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            // Add video output to session
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            print("✅ Camera session configured successfully")
            
        } catch {
            print("❌ Error setting up camera: \(error.localizedDescription)")
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                print("📷 Camera session started")
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
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
            } else {
                device.torchMode = .off
                DispatchQueue.main.async {
                    self.isFlashlightOn = false
                }
                print("💡 Flashlight OFF")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("❌ Error toggling flashlight: \(error)")
        }
    }
    
    func requestPermissionAndStartSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            print("❌ Camera access denied")
        @unknown default:
            break
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
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
        
        // Extract and print all detected text
        let detectedText = observations.compactMap { observation in
            return observation.topCandidates(1).first?.string
        }
        
        // Only process if we have detected text
        if !detectedText.isEmpty {
            print("🔍 OCR Detected Text:")
            for (index, text) in detectedText.enumerated() {
                print("   \(index + 1). \(text)")
            }
            
            // Try to parse expiration date using DateParser
            if let expirationDate = parseExpirationDateFromText(detectedText) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                print("📅 EXPIRATION DATE FOUND: \(formatter.string(from: expirationDate))")
                
                // Check if expired
                let isExpired = expirationDate < Date()
                print("⚠️  STATUS: \(isExpired ? "EXPIRED" : "VALID")")
                
                // Trigger navigation on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.detectedDate = expirationDate
                    self?.shouldNavigateToResult = true
                }
                
            } else {
                print("📅 No expiration date detected in this frame")
            }
            
            print("---")
        }
    }
    
    // MARK: - DateParser Integration
    private func parseExpirationDateFromText(_ texts: [String]) -> Date? {
        // Try to find and parse dates from all detected text strings
        for text in texts {
            if let date = attemptDateParsing(from: text) {
                return date
            }
        }
        return nil
    }
    
    private func attemptDateParsing(from text: String) -> Date? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Try different parsing strategies in order of specificity
        
        // 1. Try EXP MMM YYYY format (e.g., "EXP NOV 2027", "EXPIRES JAN 2025")
        if let date = parseExpMMMyyyy(from: cleanedText) {
            return date
        }
        
        // 2. Try DD/MM/YYYY format (e.g., "15/11/2025")
        if let date = parseDDMMMyyyy(from: cleanedText) {
            return date
        }
        
        // 3. Try DD-MM-YY format (e.g., "15-11-25")
        if let date = parseDDMMYY(from: cleanedText) {
            return date
        }
        
        // 4. Try MM/YYYY format (e.g., "11/2025")
        if let date = parseMMYYYY(from: cleanedText) {
            return date
        }
        
        // 5. Try MMYY format (e.g., "1127" for Nov 2027)
        if let date = parseMMYY(from: cleanedText) {
            return date
        }
        
        return nil
    }
    
    // MARK: - Format-specific parsing methods (copied from DateParser for integration)
    
    private func parseExpMMMyyyy(from text: String) -> Date? {
        let expPatterns = [
            #"(?:EXP|EXPIRES?)\s*([A-Z]{3})\s*(\d{4})"#,
            #"([A-Z]{3})\s*(\d{4})"#
        ]
        
        for pattern in expPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                let components = matchedText.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty && !$0.contains("EXP") }
                
                if components.count >= 2 {
                    let monthStr = components[0]
                    let yearStr = components[1]
                    
                    if let month = parseMonth(from: monthStr),
                       let year = Int(yearStr) {
                        return createDate(day: 1, month: month, year: year)
                    }
                }
            }
        }
        return nil
    }
    
    private func parseDDMMMyyyy(from text: String) -> Date? {
        let pattern = #"(\d{1,2})/(\d{1,2})/(\d{4})"#
        
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchedText = String(text[match])
            let components = matchedText.components(separatedBy: "/")
            
            if components.count == 3,
               let day = Int(components[0]),
               let month = Int(components[1]),
               let year = Int(components[2]) {
                return createDate(day: day, month: month, year: year)
            }
        }
        return nil
    }
    
    private func parseDDMMYY(from text: String) -> Date? {
        let pattern = #"(\d{1,2})-(\d{1,2})-(\d{2})"#
        
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchedText = String(text[match])
            let components = matchedText.components(separatedBy: "-")
            
            if components.count == 3,
               let day = Int(components[0]),
               let month = Int(components[1]),
               let yearTwoDigit = Int(components[2]) {
                
                let year = yearTwoDigit < 50 ? 2000 + yearTwoDigit : 1900 + yearTwoDigit
                return createDate(day: day, month: month, year: year)
            }
        }
        return nil
    }
    
    private func parseMMYYYY(from text: String) -> Date? {
        let pattern = #"(\d{1,2})/(\d{4})"#
        
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchedText = String(text[match])
            let components = matchedText.components(separatedBy: "/")
            
            if components.count == 2,
               let month = Int(components[0]),
               let year = Int(components[1]),
               month >= 1 && month <= 12 {
                return createDate(day: 1, month: month, year: year)
            }
        }
        return nil
    }
    
    private func parseMMYY(from text: String) -> Date? {
        let pattern = #"\d{4}"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                let matchedText = String(text[range])
                
                if matchedText.count == 4 {
                    let monthStr = String(matchedText.prefix(2))
                    let yearStr = String(matchedText.suffix(2))
                    
                    if let month = Int(monthStr),
                       let yearTwoDigit = Int(yearStr),
                       month >= 1 && month <= 12 {
                        
                        let year = yearTwoDigit < 50 ? 2000 + yearTwoDigit : 1900 + yearTwoDigit
                        return createDate(day: 1, month: month, year: year)
                    }
                }
            }
        }
        return nil
    }
    
    private func parseMonth(from monthStr: String) -> Int? {
        let monthMap: [String: Int] = [
            "JAN": 1, "JANUARY": 1,
            "FEB": 2, "FEBRUARY": 2,
            "MAR": 3, "MARCH": 3,
            "APR": 4, "APRIL": 4,
            "MAY": 5,
            "JUN": 6, "JUNE": 6,
            "JUL": 7, "JULY": 7,
            "AUG": 8, "AUGUST": 8,
            "SEP": 9, "SEPT": 9, "SEPTEMBER": 9,
            "OCT": 10, "OCTOBER": 10,
            "NOV": 11, "NOVEMBER": 11,
            "DEC": 12, "DECEMBER": 12
        ]
        
        return monthMap[monthStr.uppercased()]
    }
    
    private func createDate(day: Int, month: Int, year: Int) -> Date? {
        guard month >= 1 && month <= 12,
              day >= 1 && day <= 31,
              year >= 1900 && year <= 2100 else {
            return nil
        }
        
        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = month
        dateComponents.year = year
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
        
        let calendar = Calendar.current
        return calendar.date(from: dateComponents)
    }
}

// MARK: - Camera Preview Placeholder
struct CameraPreviewPlaceholder: View {
    @ObservedObject var cameraManager: CameraManager
    
    var body: some View {
        Rectangle()
            .fill(Color.black)
            .overlay(
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Camera Feed\nwith OCR Processing")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .font(.title3)
                    
                    Text("Text detection active\nCheck console for results")
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .font(.caption)
                }
            )
            .onAppear {
                cameraManager.requestPermissionAndStartSession()
            }
            .onDisappear {
                cameraManager.stopSession()
            }
    }
}

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    
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
                            // Help action will be implemented later
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
                
                // Camera feed with OCR processing
                CameraPreviewPlaceholder(cameraManager: cameraManager)
                    .ignoresSafeArea(edges: .bottom)
            }
            .background(Color.white)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $cameraManager.shouldNavigateToResult) {
                TemporaryResultView(detectedDate: cameraManager.detectedDate)
            }
        }
    }
}

// MARK: - Temporary Result View (until proper ResultView is accessible)
struct TemporaryResultView: View {
    let detectedDate: Date?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎉 Success!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let date = detectedDate {
                VStack(spacing: 8) {
                    Text("Expiration Date Found:")
                        .font(.headline)
                    
                    Text(DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: .none))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(date < Date() ? "⚠️ EXPIRED" : "✅ VALID")
                        .font(.title3)
                        .foregroundColor(date < Date() ? .red : .green)
                }
            } else {
                Text("No date information available")
                    .foregroundColor(.secondary)
            }
            
            Button("Scan Again") {
                // Navigation back handled by SwiftUI
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .navigationBarBackButtonHidden(false)
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
