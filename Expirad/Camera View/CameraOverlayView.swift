import SwiftUI

struct CameraOverlayView: View {
    let drugName: String?
    let onFlashTap: () -> Void
    let onHelpTap: () -> Void
    let onDoubleTap: () -> Void
    let isFlashOn: Bool

    var body: some View {
        ZStack {
            // Transparent overlay
            Color.black.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                // Title
                HStack {
                    if let name = drugName {
                        Text(name)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("Memindai\nNama Obat")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 4)

                // Subtitle
                HStack {
                    if drugName == nil {
                        Text("Coba beberapa sisi")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    } else {
                        Text("Ketuk layar dua kali untuk konfirmasi")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)

                Spacer()
                // Bottom buttons
                HStack {
                    Button(action: onFlashTap) {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Spacer()
                    Button(action: onHelpTap) {
                        Image(systemName: "questionmark")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onTapGesture(count: 2, perform: {
            if drugName != nil {
                onDoubleTap()
            }
        })
    }
}

struct CameraOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CameraOverlayView(drugName: nil, onFlashTap: {}, onHelpTap: {}, onDoubleTap: {}, isFlashOn: false)
                .background(Color.gray)
                .previewDisplayName("Scanning")
            CameraOverlayView(drugName: "Procold\nFlu&Batuk", onFlashTap: {}, onHelpTap: {}, onDoubleTap: {}, isFlashOn: true)
                .background(Color.gray)
                .previewDisplayName("Scanned")
        }
    }
}
