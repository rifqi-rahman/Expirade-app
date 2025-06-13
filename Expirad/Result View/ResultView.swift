//
//  ResultView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI
import AVFoundation

// MARK: - Timing Configuration  
private let RESULTVIEW_TTS_DELAY: Double = 1.0 // Time to wait before starting ResultView TTS
// Adjust this value to control when ResultView TTS starts:
// - 0.5 = Very fast (may conflict with Camera TTS)
// - 1.0 = Balanced (current) 
// - 2.0 = Very safe but slower

// MARK: - Main ResultView

struct ResultView: View {
    let detectedDate: Date?
    let detectedDrugName: String?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ttsManager = ResultViewTTS()
    @State private var hasSpoken = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation
            HStack {
                BackButtonView {
                    dismiss()
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Main Content
            if let date = detectedDate {
                ResultContentView(
                    detectedDate: date,
                    detectedDrugName: detectedDrugName
                )
            } else {
                NoDataView()
            }
            
            Spacer()
        }
        .background(Color.white)
        .navigationTitle("Hasil Pemindaian")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // CENTRALIZED TTS: Handle both cases in one place to prevent double TTS
            guard !hasSpoken else { return }
            
            // Wait for any Camera TTS to finish before starting ResultView TTS
            DispatchQueue.main.asyncAfter(deadline: .now() + RESULTVIEW_TTS_DELAY) {
                if let date = self.detectedDate {
                    // Case 1: Date detected - speak expiration result
                    let daysLeft = calculateDaysLeft(from: date)
                    let status = getExpiredStatus(for: daysLeft)
                    self.ttsManager.speakExpirationResult(
                        daysLeft: daysLeft,
                        status: status,
                        date: date,
                        drugName: self.detectedDrugName
                    )
                } else {
                    // Case 2: No date - speak no data message
                    self.ttsManager.speakNoDataMessage()
                }
            }
            hasSpoken = true
        }
        .onDisappear {
            // Stop speech when leaving the view
            ttsManager.stopSpeaking()
        }
    }
    
    // MARK: - Preview
    struct ResultView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                // Safe (Green) - More than 14 days
                ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()), detectedDrugName: "Paracetamol")
                    .previewDisplayName("Safe - 30 days with drug")
                
                // Soon (Yellow) - 5-14 days  
                ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 10, to: Date()), detectedDrugName: nil)
                    .previewDisplayName("Soon - 10 days")
                
                // Danger (Red) - 1-4 days
                ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()), detectedDrugName: "Amoxicillin")
                    .previewDisplayName("Danger - 2 days with drug")
                
                // Expired (Gray) - Past expiration
                ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()), detectedDrugName: nil)
                    .previewDisplayName("Expired - 5 days ago")
                
                // Danger (Red) - Expires today
                ResultView(detectedDate: Date(), detectedDrugName: "Vitamin C")
                    .previewDisplayName("Danger - Today with drug")
                
                // No date
                ResultView(detectedDate: nil, detectedDrugName: nil)
                    .previewDisplayName("No Date")
            }
        }
    }
}
