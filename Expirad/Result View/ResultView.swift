//
//  ResultView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI

struct ResultView: View {
    let detectedDate: Date?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation
            HStack {
                Button(action: {
                    // Navigate back to camera view
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Main Content
            if let date = detectedDate {
                let daysRemaining = calculateDaysRemaining(from: date)
                let status = getStatus(for: daysRemaining)
                
                VStack(spacing: 40) {
                    // Large Status Circle with Icon
                    ZStack {
                        Circle()
                            .fill(status.color)
                            .frame(width: 200, height: 200)
                        
                        Image(systemName: status.iconName)
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    // Status Text
                    Text(status.message)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                    
                    VStack(spacing: 8) {
                        // Days Remaining
                        Text("\(max(daysRemaining, 0))")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Hari lagi")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.black)
                    }
                    
                    VStack(spacing: 8) {
                        // Expiration Label
                        Text("Kadaluarsa")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                        
                        // Full Date
                        Text(formatDateIndonesian(date))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                
            } else {
                // No date state
                VStack(spacing: 40) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 200)
                        
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    
                    Text("Tidak Ada Data")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("Tanggal kadaluarsa tidak dapat dibaca")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Helper Functions
    
    private func calculateDaysRemaining(from date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expirationDate = calendar.startOfDay(for: date)
        
        let components = calendar.dateComponents([.day], from: today, to: expirationDate)
        return components.day ?? 0
    }
    
    private func getStatus(for daysRemaining: Int) -> (color: Color, iconName: String, message: String) {
        if daysRemaining <= 0 {
            // Danger (Red): remaining days <= 0
            return (Color.red, "xmark.circle.fill", "Bahaya!")
        } else if daysRemaining >= 1 && daysRemaining <= 30 {
            // Immediate (Yellow): remaining days between 1 and 30
            return (Color.yellow, "exclamationmark.triangle.fill", "Segera!")
        } else {
            // Safe (Green): remaining days > 30
            return (Color.green, "checkmark.circle.fill", "Aman!")
        }
    }
    
    private func formatDateIndonesian(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct ResultView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Safe (Green) - More than 30 days
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 45, to: Date()))
                .previewDisplayName("Safe - 45 days")
            
            // Immediate (Yellow) - 1-30 days  
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()))
                .previewDisplayName("Immediate - 15 days")
            
            // Immediate (Yellow) - 1 day
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()))
                .previewDisplayName("Immediate - 1 day")
            
            // Danger (Red) - Expired
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()))
                .previewDisplayName("Danger - Expired")
            
            // Danger (Red) - Expires today
            ResultView(detectedDate: Date())
                .previewDisplayName("Danger - Today")
            
            // No date
            ResultView(detectedDate: nil)
                .previewDisplayName("No Date")
        }
    }
}
