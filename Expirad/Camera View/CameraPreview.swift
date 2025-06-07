//
//  CameraPreview.swift
//  Expirad
//
//  Camera Preview Bridge for SwiftUI
//

import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit

// MARK: - Real Camera Preview for iOS
struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black
        
        // Remove any existing sublayers
        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // Add the preview layer
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer frame when the view bounds change
        DispatchQueue.main.async {
            self.previewLayer.frame = uiView.bounds
        }
    }
}

#else

// MARK: - Fallback for non-iOS platforms
struct CameraPreview: View {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    var body: some View {
        Rectangle()
            .fill(Color.black)
            .overlay(
                Text("Camera Preview\n(iOS Only)")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            )
    }
}

#endif 