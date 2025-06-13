//
//  NoDataView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI

struct NoDataView: View {
    var body: some View {
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
}

#Preview {
    NoDataView()
} 