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
    @StateObject private var cameraManager = UnifiedCameraManager()
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    CameraTopBar(cameraManager: cameraManager)
                    CameraPreviewArea(cameraManager: cameraManager)
                    Spacer()
                    HStack {
                        Button(action: { cameraManager.toggleFlashlight() }) {
                            Image(systemName: cameraManager.isFlashlightOn ? "bolt.fill" : "bolt")
                                .foregroundColor(.white)
                                .font(.system(size: 28, weight: .bold))
                                .frame(width: 48, height: 48)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                        .accessibilityLabel(cameraManager.isFlashlightOn ? "Senter menyala" : "Senter mati")
                        .accessibilityHint("Ketuk dua kali untuk menghidupkan atau mematikan senter")
                        Spacer()
                        Button(action: {
                            cameraManager.stopSpeaking()
                            let helpMessage: String
                            if cameraManager.ocrPhase == .drugName {
                                helpMessage = "Arahkan kamera ke nama obat pada kemasan. Tahan stabil sekitar 15 sentimeter. Pastikan pencahayaan cukup."
                            } else {
                                helpMessage = "Arahkan kamera ke tanggal kadaluarsa pada kemasan. Tahan stabil sekitar 15 sentimeter. Pastikan pencahayaan cukup."
                            }
                            if !UIAccessibility.isVoiceOverRunning {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    cameraManager.speakGuidance(helpMessage, priority: true)
                                }
                            }
                        }) {
                            Image(systemName: "questionmark.square")
                                .foregroundColor(.white)
                                .font(.system(size: 28, weight: .bold))
                                .frame(width: 48, height: 48)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                        .accessibilityLabel("Tombol bantuan")
                        .accessibilityHint("Ketuk dua kali untuk instruksi singkat, atau tahan lama untuk panduan lengkap")
                        .onLongPressGesture {
                            cameraManager.speakDetailedHelp()
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
                CameraBottomOverlay(
                    cameraManager: cameraManager,
                    onDrugNameConfirm: { cameraManager.userConfirmedDrugName(true) },
                    onDrugNameAppear: {
                        if let drugName = cameraManager.detectedDrugName {
                            cameraManager.speakDrugNameIfNeeded(drugName)
                        }
                    },
                    onDrugNameDisappear: { cameraManager.stopSpeaking() }
                )
            }
            .background(Color.primary)
            .navigationTitle("Kamera")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $cameraManager.shouldNavigateToResult) {
                ResultView(detectedDate: cameraManager.detectedDate, detectedDrugName: cameraManager.detectedDrugName)
            }
            .onChange(of: cameraManager.shouldNavigateToResult) { oldValue, newValue in
                if oldValue == false && newValue == true {
                    cameraManager.stopSpeaking()
                } else if oldValue == true && newValue == false {
                    cameraManager.resetForNewScan()
                }
            }
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

struct CameraTopBar: View {
    @ObservedObject var cameraManager: UnifiedCameraManager
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color.white)
    }
}

struct CameraAccessibilityStatus: View {
    @ObservedObject var cameraManager: UnifiedCameraManager
    var body: some View {
        VStack {
            Spacer()
            
            // Primary accessibility status
            Text(cameraManager.accessibilityStatus)
                .foregroundColor(.white)
                .fontWeight(.bold)
                .font(.title2)
                .multilineTextAlignment(.center)
                .shadow(color: .black, radius: 2)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .accessibilityLabel(cameraManager.accessibilityStatus)
                .accessibilityAddTraits(.updatesFrequently)
            
            Spacer().frame(height: 40)
            
            // Tap to focus hint (VoiceOver friendly)
            Text(cameraManager.ocrPhase == .drugName ? "Ketuk tengah layar untuk membantu fokus kamera pada nama obat" : "Ketuk tengah layar untuk membantu fokus kamera pada tanggal kadaluarsa")
                .foregroundColor(.white.opacity(0.8))
                .font(.body)
                .multilineTextAlignment(.center)
                .shadow(color: .black, radius: 1)
                .accessibilityLabel(cameraManager.ocrPhase == .drugName ? "Ketuk tengah layar untuk membantu kamera fokus pada nama obat" : "Ketuk tengah layar untuk membantu kamera fokus pada tanggal kadaluarsa")
                .accessibilityHint("Ketuk dua kali untuk mengaktifkan fokus kamera")
            
            Spacer().frame(height: 30)
        }
    }
}

struct CameraPreviewArea: View {
    @ObservedObject var cameraManager: UnifiedCameraManager
    var body: some View {
        ZStack {
            if let previewLayer = cameraManager.previewLayer, cameraManager.isCameraActive {
                ZStack {
                    CameraPreview(previewLayer: previewLayer)
                        .id(cameraManager.previewRefreshID) // Force refresh when ID changes
                        .onTapGesture {
                            // Help camera focus when user taps screen (VoiceOver-aware)
                            if !UIAccessibility.isVoiceOverRunning {
                                cameraManager.speakGuidance("Memfokuskan kamera", priority: false)
                            }
                        }
                        .accessibilityLabel("Jendela bidik kamera")
                        .accessibilityHint(cameraManager.ocrPhase == .drugName ? "Ketuk dua kali untuk membantu kamera fokus pada nama obat" : "Ketuk dua kali untuk membantu kamera fokus pada tanggal kadaluarsa")
                    
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
                            .accessibilityLabel("Kamera aktif")
                            .accessibilityHint("Indikator bahwa kamera sedang berjalan")
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text(cameraManager.ocrPhase == .drugName ? "DRUG" : "DATE")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(20)
                            .accessibilityLabel(cameraManager.ocrPhase == .drugName ? "Pemindai nama obat aktif" : "Pemindai tanggal aktif")
                            .accessibilityHint(cameraManager.ocrPhase == .drugName ? "Indikator bahwa sistem sedang mencari nama obat" : "Indikator bahwa sistem sedang mencari tanggal kadaluarsa")
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
                    .accessibilityLabel("Memuat kamera")
                    .accessibilityHint(cameraManager.ocrPhase == .drugName ? "Kamera sedang mempersiapkan diri untuk memindai nama obat" : "Kamera sedang mempersiapkan diri untuk memindai tanggal kadaluarsa")
            }
        }
    }
}

struct DrugNameConfirmationOverlay: View {
    let drugName: String
    let onConfirm: () -> Void
    let onAppearTTS: () -> Void
    let onDisappearTTS: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Text(drugName)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(radius: 4)
                    .padding(.horizontal, 16)
                Spacer()
                Text("Ketuk layar dua kali untuk konfirmasi")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
            }
        }
        .onAppear(perform: onAppearTTS)
        .onDisappear(perform: onDisappearTTS)
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded { onConfirm() }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Obat terdeteksi: \(drugName). Ketuk dua kali untuk konfirmasi.")
    }
}

struct CameraBottomOverlay: View {
    @ObservedObject var cameraManager: UnifiedCameraManager
    var onDrugNameConfirm: (() -> Void)? = nil
    var onDrugNameAppear: (() -> Void)? = nil
    var onDrugNameDisappear: (() -> Void)? = nil
    
    var body: some View {
        VStack {
            Spacer()
            if cameraManager.ocrPhase == .drugName {
                if let drugName = cameraManager.detectedDrugName {
                    // Drug name detected, show confirmation overlay
                    VStack(alignment: .center, spacing: 8) {
                        Text(drugName)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(radius: 4)
                            .padding(.horizontal, 16)
                        Text("Ketuk layar dua kali untuk konfirmasi")
                            .font(.title3)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.black.opacity(0.01)) // for tap gesture
                    .onAppear { onDrugNameAppear?() }
                    .onDisappear { onDrugNameDisappear?() }
                    .highPriorityGesture(
                        TapGesture(count: 2)
                            .onEnded { onDrugNameConfirm?() }
                    )
                } else {
                    // No drug name detected, show scanning overlay
                    VStack(alignment: .center, spacing: 8) {
                        Text("Memindai\nNama Obat")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(radius: 4)
                            .padding(.horizontal, 16)
                        Text("Coba beberapa sisi")
                            .font(.title3)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            Spacer().frame(height: 100) // Space for buttons
        }
        .animation(.easeInOut, value: cameraManager.detectedDrugName)
        .allowsHitTesting(cameraManager.ocrPhase == .drugName && cameraManager.detectedDrugName != nil)
    }
}

#Preview {
    ContentView()
}
