//
//  BackButtonView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI

struct BackButtonView: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("Tombol kembali")
        .accessibilityHint("Ketuk dua kali untuk kembali ke kamera pemindai")
    }
}

#Preview {
    BackButtonView {
        print("Back button tapped")
    }
} 