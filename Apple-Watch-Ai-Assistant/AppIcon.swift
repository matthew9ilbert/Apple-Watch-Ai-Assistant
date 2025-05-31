import SwiftUI

struct AppIcon: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            // Central icon elements
            ZStack {
                // Watch outline
                Circle()
                    .strokeBorder(Color.white, lineWidth: 8)
                    .frame(width: 180, height: 180)
                
                // AI/assistant visualization
                VStack(spacing: 5) {
                    // Assistant waveform/brain visualization
                    HStack(spacing: 6) {
                        ForEach(0..<5) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 4, height: getHeight(for: i))
                        }
                    }
                    
                    // Watch face with smart features
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            ZStack {
                                // Clock hands
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 2, height: 30)
                                    .offset(y: -15)
                                
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 2, height: 20)
                                    .offset(y: -10)
                                    .rotated(by: .degrees(45))
                                
                                // Heart rate indicator
                                Path { path in
                                    path.move(to: CGPoint(x: -20, y: 15))
                                    path.addLine(to: CGPoint(x: -10, y: 15))
                                    path.addLine(to: CGPoint(x: -5, y: 5))
                                    path.addLine(to: CGPoint(x: 0, y: 25))
                                    path.addLine(to: CGPoint(x: 5, y: 15))
                                    path.addLine(to: CGPoint(x: 10, y: 15))
                                    path.addLine(to: CGPoint(x: 15, y: 5))
                                    path.addLine(to: CGPoint(x: 20, y: 15))
                                }
                                .stroke(Color.white, lineWidth: 2)
                                .offset(y: 10)
                            }
                        )
                }
            }
        }
    }
    
    // Helper function to create varied waveform heights
    private func getHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [35, 60, 45, 70, 30]
        return heights[index % heights.count]
    }
}

extension View {
    func rotated(by angle: Angle) -> some View {
        self.rotationEffect(angle)
    }
}

// Preview provider
struct AppIcon_Previews: PreviewProvider {
    static var previews: some View {
        AppIcon()
            .previewLayout(.fixed(width: 512, height: 512))
    }
}
