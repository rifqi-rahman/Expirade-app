//
//  ExpiredStatus.swift
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

func calculateDaysLeft(from date: Date) -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let expirationDate = calendar.startOfDay(for: date)
    
    let components = calendar.dateComponents([.day], from: today, to: expirationDate)
    return components.day ?? 0
}

func getExpiredStatus(for daysLeft: Int) -> ExpiredStatus {
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