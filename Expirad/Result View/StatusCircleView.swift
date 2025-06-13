//
//  StatusCircleView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI

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

#Preview {
    VStack(spacing: 20) {
        StatusCircleView(status: .safe)
        StatusCircleView(status: .soon)
        StatusCircleView(status: .danger)
        StatusCircleView(status: .expired)
    }
} 