//
//  ResultView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI

enum ExpiredStatus {
    case safe, soon, danger, expired
    
    var color: Color {
        switch self {
        case .safe: return .green
        case .soon: return .yellow
        case .danger: return .red
        case .expired: return .gray
        }
    }
    
    var message: String {
        switch self {
        case .safe: return "Aman!"
        case .soon: return "Segera!"
        case .danger: return "Bahaya!"
        case .expired: return "Tidak Bisa Dipakai!"
        }
    }
    
    var iconName: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .soon: return "exclamationmark.triangle.fill"
        case .danger: return "exclamationmark.circle.fill"
        case .expired: return "xmark.circle.fill"
        }
    }
}

// MARK: - Helper Functions for Indonesian Text
func angkaKeTeks(_ angka: Int) -> String {
    let satuan = ["", "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan"]
    let belasan = ["sepuluh", "sebelas", "dua belas", "tiga belas", "empat belas", "lima belas", "enam belas", "tujuh belas", "delapan belas", "sembilan belas"]
    let puluhan = ["", "", "dua puluh", "tiga puluh", "empat puluh", "lima puluh", "enam puluh", "tujuh puluh", "delapan puluh", "sembilan puluh"]
    
    if angka < 0 {
        return "minus \(angkaKeTeks(-angka))"
    } else if angka < 10 {
        return satuan[angka]
    } else if angka < 20 {
        return belasan[angka - 10]
    } else if angka < 100 {
        let puluh = angka / 10
        let sisa = angka % 10
        return "\(puluhan[puluh])\(sisa > 0 ? " \(satuan[sisa])" : "")"
    } else {
        return "\(angka)"
    }
}

// MARK: - Modular Components

struct StatusCircleView: View {
    let status: ExpiredStatus
    
    var iconName: String {
        switch status {
        case .expired:
            return "xmark"
        case .danger:
            return "exclamationmark.triangle"
        case .soon:
            return "exclamationmark.circle"
        case .safe:
            return "checkmark"
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(status.color)
                .frame(width: 200, height: 200)
            
            Image(systemName: iconName)
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(.black)
                .accessibilityHidden(true)
                .accessibilityElement()
                .accessibilityLabel("Status: \(status.message)")
        }
    }
}

struct CountdownTextView: View {
    let daysLeft: Int
    
    var body: some View {
        let absoluteDays = abs(daysLeft)
        let isOverdue = daysLeft < 0
        
        VStack(spacing: 4) {
            Text("\(absoluteDays)")
                .font(.system(size: 80, weight: .bold))
                .accessibilityLabel(
                    isOverdue 
                    ? "Terlewat \(angkaKeTeks(absoluteDays)) hari"
                    : "Tersisa \(angkaKeTeks(absoluteDays)) hari"
                )
            
            Text(isOverdue ? "Hari lalu" : "Hari lagi")
                .font(.title3)
                .accessibilityHidden(true)
        }
    }
}

struct ExpirationDateView: View {
    let expirationDate: Date
    
    var spokenDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: expirationDate)
    }
    
    var body: some View {
        let formattedDate = expirationDate.formatted(date: .numeric, time: .omitted)
        
        VStack(spacing: 4) {
            Text("Kadaluarsa")
                .font(.title3)
                .accessibilityHidden(true)
            
            Text(formattedDate)
                .font(.title)
                .bold()
                .accessibilityLabel("Tanggal kadaluarsa: \(spokenDate)")
        }
    }
}

// MARK: - Main ResultView

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
                let daysLeft = calculateDaysLeft(from: date)
                let status = getExpiredStatus(for: daysLeft)
                
                VStack(spacing: 40) {
                    // Status Circle Component
                    StatusCircleView(status: status)
                        .frame(width: 200, height: 200)
                    
                    // Status Text
                    Text(status.message)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                    
                    // Countdown Text Component with Indonesian numbers
                    CountdownTextView(daysLeft: daysLeft)
                        .foregroundColor(.black)
                    
                    // Expiration Date Component
                    ExpirationDateView(expirationDate: date)
                        .foregroundColor(.black)
                        .padding(.top, 24)
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
            // Safe (Green) - More than 14 days
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()))
                .previewDisplayName("Safe - 30 days")
            
            // Soon (Yellow) - 5-14 days  
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 10, to: Date()))
                .previewDisplayName("Soon - 10 days")
            
            // Danger (Red) - 1-4 days
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()))
                .previewDisplayName("Danger - 2 days")
            
            // Expired (Gray) - Past expiration
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()))
                .previewDisplayName("Expired - 5 days ago")
            
            // Danger (Red) - Expires today
            ResultView(detectedDate: Date())
                .previewDisplayName("Danger - Today")
            
            // No date
            ResultView(detectedDate: nil)
                .previewDisplayName("No Date")
        }
    }
}
