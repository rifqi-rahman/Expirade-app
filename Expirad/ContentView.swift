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
                            // Help action - speak guidance
                            cameraManager.stopSpeaking()
                            let helpMessage = "Arahkan hape kamera ke arah kemasan obat"
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
                            
                            // Enhanced positioning guidance
                            Text(cameraManager.positioningGuidance)
                                .foregroundColor(.yellow)
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .fontWeight(.semibold)
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
            .navigationDestination(isPresented: $cameraManager.shouldNavigateToResult) {
                ResultView(detectedDate: cameraManager.detectedDate)
            }
            .onChange(of: cameraManager.shouldNavigateToResult) { oldValue, newValue in
                // When returning from ResultView (newValue becomes false)
                if oldValue == true && newValue == false {
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
