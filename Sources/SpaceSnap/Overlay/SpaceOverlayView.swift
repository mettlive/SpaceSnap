import SwiftUI
import SpaceSnapCore

struct SpaceOverlayView: View {
    let displaySpaces: DisplaySpaces?

    var body: some View {
        VStack(spacing: 12) {
            centerContent
            dots
        }
        .frame(width: 180, height: 120)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var centerContent: some View {
        if let displaySpaces, displaySpaces.currentSpace.kind == .fullscreen {
            Image(systemName: "rectangle.fill")
                .font(.system(size: 40))
        } else if let number = displaySpaces?.currentDesktopNumber {
            Text("\(number)")
                .font(.system(size: 48, weight: .semibold, design: .rounded))
        } else {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 40))
        }
    }

    @ViewBuilder
    private var dots: some View {
        if let displaySpaces {
            HStack(spacing: 6) {
                ForEach(Array(displaySpaces.spaces.enumerated()), id: \.element.id) { index, space in
                    switch space.kind {
                    case .desktop:
                        Circle()
                            .fill(index == displaySpaces.currentIndex ? Color.primary : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                    case .fullscreen:
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 10, height: 6)
                    }
                }
            }
        }
    }
}
