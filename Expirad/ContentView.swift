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
            VStack(spacing: 0) {
                // Buttons section  
                VStack(spacing: 16) {
                    // Buttons HStacmek
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
                        .accessibilityLabel(cameraManager.isFlashlightOn ? "Senter menyala" : "Senter mati")
                        .accessibilityHint("Ketuk dua kali untuk menghidupkan atau mematikan senter")
                        
                        Spacer()
                        
                        // Help button
                        Button(action: {
                            // Quick help action - speak basic guidance
                            cameraManager.stopSpeaking()
                            let helpMessage = "Arahkan kamera ke tanggal kadaluarsa pada kemasan obat. Tahan stabil sekitar 15 sentimeter. Pastikan pencahayaan cukup."
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                cameraManager.speakGuidance(helpMessage, priority: true)
                            }
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                                .frame(width: 60, height: 60)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("Tombol bantuan")
                        .accessibilityHint("Ketuk dua kali untuk instruksi singkat, atau tahan lama untuk panduan lengkap")
                        .onLongPressGesture {
                            // Detailed help on long press
                            cameraManager.speakDetailedHelp()
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
                                .id(cameraManager.previewRefreshID) // Force refresh when ID changes
                                .onTapGesture {
                                    // Help camera focus when user taps screen
                                    cameraManager.speakGuidance("Memfokuskan kamera", priority: false)
                                }
                                .accessibilityLabel("Jendela bidik kamera")
                                .accessibilityHint("Ketuk dua kali untuk membantu kamera fokus pada tanggal kadaluarsa")
                            
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
                                        Text("OCR")
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(20)
                                    .accessibilityLabel("Pemindai teks aktif")
                                    .accessibilityHint("Indikator bahwa sistem pembaca teks sedang berjalan")
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
                            .accessibilityHint("Kamera sedang mempersiapkan diri untuk memindai tanggal kadaluarsa")
                    }
                    
                    // Clean accessibility status for VoiceOver users
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
                        Text("Ketuk tengah layar untuk membantu fokus kamera")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black, radius: 1)
                            .accessibilityLabel("Ketuk tengah layar untuk membantu kamera fokus pada tanggal kadaluarsa")
                            .accessibilityHint("Ketuk dua kali untuk mengaktifkan fokus kamera")
                        
                        Spacer().frame(height: 30)
                    }
                }
            }
            .background(Color.white)
            .navigationTitle("Kamera")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $cameraManager.shouldNavigateToResult) {
                ResultView(detectedDate: cameraManager.detectedDate)
            }
            .onChange(of: cameraManager.shouldNavigateToResult) { oldValue, newValue in
                // When navigating TO ResultView (newValue becomes true)
                if oldValue == false && newValue == true {
                    // Stop Camera TTS immediately to prevent conflicts with ResultView TTS
                    cameraManager.stopSpeaking()
                }
                // When returning FROM ResultView (newValue becomes false)  
                else if oldValue == true && newValue == false {
                    // Reset camera for new scan
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

#Preview {
    ContentView()
}
