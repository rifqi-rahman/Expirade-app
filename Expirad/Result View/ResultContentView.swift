//
//  ResultContentView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI

struct ResultContentView: View {
    let detectedDate: Date
    let detectedDrugName: String?
    
    var body: some View {
        let daysLeft = calculateDaysLeft(from: detectedDate)
        let status = getExpiredStatus(for: daysLeft)
        
        VStack(spacing: 40) {
            // Drug Name Component (if available)
            if let drugName = detectedDrugName {
                DrugNameView(drugName: drugName)
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
            }
            
            // Status Circle Component
            StatusCircleView(status: status)
                .frame(width: 200, height: 200)
            
            // Status Text
            Text(status.message)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.black)
                .accessibilityLabel("Status obat: \(status.message)")
                .accessibilityHint("Kondisi keamanan penggunaan obat berdasarkan tanggal kadaluarsa")
            
            // Countdown Text Component with Indonesian numbers
            CountdownTextView(daysLeft: daysLeft)
                .foregroundColor(.black)
            
            // Expiration Date Component
            ExpirationDateView(expirationDate: detectedDate)
                .foregroundColor(.black)
                .padding(.top, 24)
        }
    }
    
    // MARK: - Helper Functions
    private func calculateDaysLeft(from date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expirationDate = calendar.startOfDay(for: date)
        
        let components = calendar.dateComponents([.day], from: today, to: expirationDate)
        return components.day ?? 0
    }
    
    private func getExpiredStatus(for daysLeft: Int) -> ExpiredStatus {
        if daysLeft < 0 {
            return .expired
        } else if daysLeft <= 4 {
            return .danger
        } else if daysLeft <= 14 {
            return .soon
        } else {
            return .safe
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ResultContentView(
            detectedDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
            detectedDrugName: "Paracetamol"
        )
        
        ResultContentView(
            detectedDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            detectedDrugName: nil
        )
    }
} 