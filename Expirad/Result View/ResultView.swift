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

struct DrugNameView: View {
    let drugName: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Nama Obat")
                .font(.title3)
                .accessibilityHidden(true)
            
            Text(drugName)
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
                .accessibilityLabel("Nama obat: \(drugName)")
        }
    }
}

// MARK: - Main ResultView

struct ResultView: View {
    let detectedDate: Date?
    let detectedDrugName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var hasSpoken = false
    
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
                .accessibilityLabel("Tombol kembali")
                .accessibilityHint("Ketuk dua kali untuk kembali ke kamera pemindai")
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
                    .accessibilityLabel("Tidak ada data ditemukan")
                    .accessibilityHint("Tanggal kadaluarsa tidak berhasil dideteksi dari gambar")
                    
                    Text("Tidak Ada Data")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                        .accessibilityLabel("Tidak ada data")
                        .accessibilityHint("Pemindaian tanggal kadaluarsa tidak berhasil")
                    
                    Text("Tanggal kadaluarsa tidak dapat dibaca")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .accessibilityLabel("Tanggal kadaluarsa tidak dapat dibaca dari gambar. Silakan coba lagi dengan pencahayaan yang lebih baik.")
                        .accessibilityHint("Petunjuk untuk mencoba pemindaian ulang")
                }
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
                    let daysLeft = self.calculateDaysLeft(from: date)
                    let status = self.getExpiredStatus(for: daysLeft)
                    self.speakExpirationResult(daysLeft: daysLeft, status: status, date: date)
                } else {
                    // Case 2: No date - speak no data message
                    self.speakNoDataMessage()
                }
            }
            hasSpoken = true
        }
        .onDisappear {
            // Stop speech when leaving the view
            speechSynthesizer.stopSpeaking(at: .immediate)
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
    
    private func formatDateIndonesian(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    private func speakExpirationResult(daysLeft: Int, status: ExpiredStatus, date: Date) {
        // SAFETY: Stop any lingering TTS before starting our own
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        // Create Indonesian date formatter for speech
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "id_ID")
        dateFormatter.dateFormat = "d MMMM yyyy"
        let spokenDate = dateFormatter.string(from: date)
        
        // Create speech message based on status
        var message: String
        
        // Add drug name to the beginning if available
        let drugPrefix = detectedDrugName != nil ? "Obat \(detectedDrugName!). " : "Obat. "
        
        if daysLeft < 0 {
            let daysPast = abs(daysLeft)
            message = "\(drugPrefix)\(status.message). Obat sudah kadaluarsa \(angkaKeTeks(daysPast)) hari yang lalu. Tanggal kadaluarsa \(spokenDate). Jangan gunakan obat ini."
        } else if daysLeft == 0 {
            message = "\(drugPrefix)\(status.message). Obat kadaluarsa hari ini, tanggal \(spokenDate). Sebaiknya jangan digunakan."
        } else if daysLeft <= 4 {
            message = "\(drugPrefix)\(status.message). Obat akan kadaluarsa dalam \(angkaKeTeks(daysLeft)) hari lagi. Tanggal kadaluarsa \(spokenDate). Segera gunakan."
        } else if daysLeft <= 14 {
            message = "\(drugPrefix)\(status.message). Obat akan kadaluarsa dalam \(angkaKeTeks(daysLeft)) hari lagi. Tanggal kadaluarsa \(spokenDate)."
        } else {
            message = "\(drugPrefix)\(status.message). Obat masih aman digunakan. Akan kadaluarsa dalam \(angkaKeTeks(daysLeft)) hari lagi, tanggal \(spokenDate)."
        }
        
        // Configure and speak
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5 // Slower speech rate for better comprehension
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    private func speakNoDataMessage() {
        // SAFETY: Stop any lingering TTS before starting our own
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        let message = "Tidak ada data. Tanggal kadaluarsa tidak dapat dibaca dari gambar. Silakan coba lagi dengan memfokuskan kamera pada tanggal kadaluarsa yang lebih jelas."
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
}

// MARK: - Preview
struct ResultView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Safe (Green) - More than 14 days
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()), detectedDrugName: nil)
                .previewDisplayName("Safe - 30 days")
            
            // Soon (Yellow) - 5-14 days  
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 10, to: Date()), detectedDrugName: nil)
                .previewDisplayName("Soon - 10 days")
            
            // Danger (Red) - 1-4 days
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()), detectedDrugName: nil)
                .previewDisplayName("Danger - 2 days")
            
            // Expired (Gray) - Past expiration
            ResultView(detectedDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()), detectedDrugName: nil)
                .previewDisplayName("Expired - 5 days ago")
            
            // Danger (Red) - Expires today
            ResultView(detectedDate: Date(), detectedDrugName: nil)
                .previewDisplayName("Danger - Today")
            
            // No date
            ResultView(detectedDate: nil, detectedDrugName: nil)
                .previewDisplayName("No Date")
        }
    }
}
