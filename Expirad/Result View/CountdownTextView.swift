//
//  CountdownTextView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI

struct CountdownTextView: View {
    let daysLeft: Int
    
    var body: some View {
        let absoluteDays = abs(daysLeft)
        let isOverdue = daysLeft < 0
        
        VStack(spacing: 4) {
            Text("\(absoluteDays)")
                .font(.system(size: 80, weight: .bold))
                .minimumScaleFactor(0.5)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                .accessibilityLabel(
                    isOverdue 
                    ? "Terlewat \(angkaKeTeks(absoluteDays)) hari"
                    : "Tersisa \(angkaKeTeks(absoluteDays)) hari"
                )
            
            Text(isOverdue ? "Hari lalu" : "Hari lagi")
                .font(.title3)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 20) {
        CountdownTextView(daysLeft: 30)
        CountdownTextView(daysLeft: 10)
        CountdownTextView(daysLeft: 2)
        CountdownTextView(daysLeft: 0)
        CountdownTextView(daysLeft: -5)
    }
} 