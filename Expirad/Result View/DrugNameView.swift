//
//  DrugNameView.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import SwiftUI

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

#Preview {
    VStack(spacing: 20) {
        DrugNameView(drugName: "Paracetamol")
        DrugNameView(drugName: "Amoxicillin 500mg")
        DrugNameView(drugName: "Vitamin C")
    }
} 