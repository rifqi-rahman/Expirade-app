//
//  ResultViewTTS.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import AVFoundation

class ResultViewTTS: ObservableObject {
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    func speakExpirationResult(daysLeft: Int, status: ExpiredStatus, date: Date, drugName: String?) {
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
        let drugPrefix = drugName != nil ? "Obat \(drugName!). " : "Obat. "
        
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
    
    func speakNoDataMessage() {
        // SAFETY: Stop any lingering TTS before starting our own
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        let message = "Tidak ada data. Tanggal kadaluarsa tidak dapat dibaca dari gambar. Silakan coba lagi dengan memfokuskan kamera pada tanggal kadaluarsa yang lebih jelas."
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
} 