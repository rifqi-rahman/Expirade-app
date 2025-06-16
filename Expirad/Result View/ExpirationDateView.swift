//
//  ExpirationDateView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI

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

#Preview {
    VStack(spacing: 20) {
        ExpirationDateView(expirationDate: Date())
        ExpirationDateView(expirationDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!)
        ExpirationDateView(expirationDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!)
    }
} 