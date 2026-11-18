import SwiftUI

struct CardModifier: ViewModifier {
    var fill: Color = Palette.card
    func body(content: Content) -> some View {
        content
            .padding(Metrics.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
    }
}

extension View {
    func card(_ fill: Color = Palette.card) -> some View { modifier(CardModifier(fill: fill)) }
}

struct FilledButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, light }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        let (bg, fg, border): (Color, Color, Color) = {
            switch kind {
            case .primary: return (Palette.accent, .white, Palette.accent)
            case .secondary: return (Palette.card, Palette.ink, Color(hex: 0xCBD3C9))
            case .light: return (.white, Color(hex: 0x0B3D35), .white)
            }
        }()
        return configuration.label
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, minHeight: Metrics.control)
            .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(border, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct ChipView: View {
    let label: String
    let selected: Bool
    var warm = false
    let action: () -> Void

    var body: some View {
        let on: (bg: Color, border: Color, fg: Color) = warm
            ? (Palette.warmSoft, Palette.warmDark, Palette.warmInk)
            : (Palette.accentSoft, Palette.accent, Palette.accentDark)
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? on.fg : Palette.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(selected ? on.bg : Palette.card, in: Capsule())
                .overlay(Capsule().stroke(selected ? on.border : Palette.fieldBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct RingView<Content: View>: View {
    let progress: Double
    var size: CGFloat = 112
    var stroke: CGFloat = 12
    var color: Color = Palette.accent
    var track: Color = Palette.lineSoft
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: stroke)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)
            content
        }
        .frame(width: size, height: size)
    }
}

/// Five-step scale used for severity and food noise.
struct ScaleView: View {
    let value: Int?
    let words: [String]
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { n in
                let on = value == n
                let hot = n >= 4
                let fill = on ? (hot ? Palette.warmDark : Palette.accent) : Palette.field
                Button { onChange(n) } label: {
                    Capsule()
                        .fill(on ? Color.white : (hot ? Palette.warm : Palette.accent))
                        .frame(width: 16, height: CGFloat(8 + n * 5))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? fill : Palette.fieldBorder, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(n), \(words[n])")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Minus / value / plus control.
struct StepperView: View {
    @Binding var value: Int
    let unit: String
    var step = 5
    var range: ClosedRange<Int> = 0...999

    var body: some View {
        HStack(spacing: 8) {
            stepButton("minus", label: "Decrease") { value = max(range.lowerBound, value - step) }
            Text("\(value) \(unit)")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .frame(minWidth: 72)
            stepButton("plus", label: "Increase") { value = min(range.upperBound, value + step) }
        }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 44, height: 44)
                .background(Palette.neutralSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 16)
            .frame(minHeight: Metrics.control)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.fieldBorder, lineWidth: 1.5))
    }
}

extension View {
    func fieldStyle() -> some View { modifier(FieldStyle()) }
}

/// Lays out chips in rows that wrap.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
