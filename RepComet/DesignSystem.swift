import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum RCTheme {
    private static var palette: RCPalette { RCAppearance.shared.selected.palette }
    static var background: Color { Color(hex: palette.background) }
    static var card: Color { Color(hex: palette.card) }
    static var border: Color { Color(hex: palette.border) }
    static var text: Color { Color(hex: palette.text) }
    static var muted: Color { Color(hex: palette.muted) }
    static var accent: Color { Color(hex: palette.accent) }
    static var accentText: Color { Color(hex: palette.accentText) }
    static var secondary: Color { Color(hex: palette.secondary) }
    static var onAccent: Color { Color(hex: palette.onAccent) }
    static var heroStart: Color { Color(hex: palette.heroStart) }
    static var heroEnd: Color { Color(hex: palette.heroEnd) }
    static var orbHighlight: Color { Color(hex: palette.orbHighlight) }
    static var orbMid: Color { Color(hex: palette.orbMid) }
    static var orbShadow: Color { Color(hex: palette.orbShadow) }

    static func impact() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

struct RCBackground: View {
    var body: some View {
        RCTheme.background.ignoresSafeArea()
    }
}

struct RCSurface: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content.padding(padding)
            .background(RCTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(RCTheme.border, lineWidth: 1))
    }
}

extension View {
    func rcSurface(padding: CGFloat = 20) -> some View { modifier(RCSurface(padding: padding)) }
    @ViewBuilder
    func rcWorkoutPresentation<Presentation: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Presentation) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
    @ViewBuilder
    func rcHideNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

struct RCHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .heavy)).tracking(-1.2).foregroundStyle(RCTheme.text)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(RCTheme.muted).lineSpacing(4) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RCPrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button { RCTheme.impact(); action() } label: {
            HStack(spacing: 12) {
                Text(title).font(.system(.headline, design: .rounded))
                Spacer(minLength: 8)
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .bold, design: .rounded)) }
            }.foregroundStyle(RCTheme.onAccent).padding(.horizontal, 22).frame(minHeight: 56)
                .background(RCTheme.accent, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }.buttonStyle(RCPressStyle())
    }
}

struct RCSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }.font(.system(.headline, design: .rounded)).foregroundStyle(RCTheme.text)
                .frame(maxWidth: .infinity).frame(minHeight: 50)
                .background(RCTheme.border.opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(RCPressStyle())
    }
}

struct RCSymbolBadge: View {
    let symbol: String
    var color: Color = RCTheme.accent
    var body: some View {
        Image(systemName: symbol).font(.system(size: 20, weight: .medium)).foregroundStyle(color)
            .frame(width: 48, height: 48).background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(color.opacity(0.15), lineWidth: 1))
    }
}

struct RCEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            RCSymbolBadge(symbol: symbol)
            Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(RCTheme.text)
            Text(message).font(.subheadline).foregroundStyle(RCTheme.muted)
                .multilineTextAlignment(.center).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 22).padding(.horizontal, 16).frame(maxWidth: .infinity)
    }
}

struct PepBuddy: View {
    @Environment(\.pepReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var moving: Bool { !reduceMotion && RCAppearance.shared.motionEnabled && scenePhase == .active }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !moving)) { timeline in
                let time = moving ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 20) : 0
                PepBuddyGraphic(time: time)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }.accessibilityHidden(true)
    }
}

private struct PepBuddyGraphic: View {
    let time: Double

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let phase = time * .pi * 2 / 4
            let ink = Color(hex: 0x282239)
            context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            context.scaleBy(x: side / 160, y: side / 160)
            context.translateBy(x: 80, y: 80 + sin(phase) * 2)
            context.rotate(by: .degrees(sin(phase) * 3))
            context.translateBy(x: -80, y: -80)

            // The limbs sit behind the body, with a small friendly wave.
            var arms = Path()
            arms.move(to: CGPoint(x: 35, y: 79))
            arms.addQuadCurve(to: CGPoint(x: 15, y: 99), control: CGPoint(x: 17, y: 83))
            arms.move(to: CGPoint(x: 126, y: 78))
            arms.addQuadCurve(to: CGPoint(x: 144 + sin(phase) * 3, y: 53), control: CGPoint(x: 145, y: 79))
            context.stroke(arms, with: .color(ink), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            context.fill(Path(roundedRect: CGRect(x: 43, y: 119, width: 27, height: 18), cornerRadius: 9), with: .color(ink))
            context.fill(Path(roundedRect: CGRect(x: 91, y: 119, width: 27, height: 18), cornerRadius: 9), with: .color(ink))

            let body = Path(roundedRect: CGRect(x: 30, y: 29, width: 100, height: 97), cornerRadius: 35)
            context.fill(body, with: .color(RCTheme.orbHighlight))
            var bandContext = context
            bandContext.clip(to: body)
            bandContext.fill(Path(roundedRect: CGRect(x: 28, y: 41, width: 104, height: 16), cornerRadius: 8), with: .color(RCTheme.orbShadow))
            bandContext.fill(Path(roundedRect: CGRect(x: 39, y: 47, width: 82, height: 3), cornerRadius: 1.5), with: .color(.white))

            context.fill(Path(ellipseIn: CGRect(x: 47, y: 88, width: 13, height: 7)), with: .color(RCTheme.orbMid))
            context.fill(Path(ellipseIn: CGRect(x: 106, y: 88, width: 13, height: 7)), with: .color(RCTheme.orbMid))
            let blinkPhase = time.truncatingRemainder(dividingBy: 5)
            let blink = max(0, 1 - abs(blinkPhase - 4.88) / 0.1)
            let eyeHeight = 13 - 12 * blink
            for x in [61.0, 95.0] {
                context.fill(Path(roundedRect: CGRect(x: x, y: 70 + (13 - eyeHeight) / 2, width: 7, height: eyeHeight), cornerRadius: 3.5), with: .color(ink))
            }
            var smile = Path()
            smile.move(to: CGPoint(x: 67, y: 91))
            smile.addQuadCurve(to: CGPoint(x: 96, y: 91), control: CGPoint(x: 82, y: 111))
            context.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }
}

struct RCSectionLabel: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title).font(.system(size: 18, weight: .bold, design: .rounded)).tracking(-0.4).foregroundStyle(RCTheme.text)
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(RCTheme.muted) }
        }
    }
}

struct RCFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(15).background(RCTheme.background, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(RCTheme.border, lineWidth: 1))
    }
}

struct RCPressStyle: ButtonStyle {
    @Environment(\.pepReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion && RCAppearance.shared.motionEnabled ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion || !RCAppearance.shared.motionEnabled ? nil : .spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct RCEntrance: ViewModifier {
    let delay: Double
    @Environment(\.pepReduceMotion) private var reduceMotion
    @State private var appeared = false
    private var animated: Bool { !reduceMotion && RCAppearance.shared.motionEnabled }

    func body(content: Content) -> some View {
        content.opacity(appeared || !animated ? 1 : 0)
            .offset(y: appeared || !animated ? 0 : 10)
            .onAppear {
                withAnimation(animated ? .spring(response: 0.48, dampingFraction: 0.88).delay(delay) : nil) { appeared = true }
            }
    }
}

extension View {
    func rcEntrance(delay: Double = 0) -> some View { modifier(RCEntrance(delay: delay)) }
}

struct RCCompletionMark: View {
    @Environment(\.pepReduceMotion) private var reduceMotion
    @State private var appeared = false
    private var animated: Bool { !reduceMotion && RCAppearance.shared.motionEnabled }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous).fill(RCTheme.heroStart)
                .frame(width: 145, height: 145).rotationEffect(.degrees(-8))
                .scaleEffect(appeared || !animated ? 1 : 0.7)
            PepBuddy().frame(width: 155, height: 155)
                .scaleEffect(appeared || !animated ? 1 : 0.4)
            ForEach(0..<5) { index in
                let angle = Double(index) * .pi * 2 / 5 - .pi / 2
                Image(systemName: "sparkle").font(.system(size: index % 2 == 0 ? 12 : 8))
                    .foregroundStyle(index % 2 == 0 ? RCTheme.secondary : RCTheme.accent)
                    .offset(x: cos(angle) * (appeared || !animated ? 81 : 30), y: sin(angle) * (appeared || !animated ? 81 : 30))
                    .opacity(appeared || !animated ? 0.85 : 0)
            }
        }.frame(height: 176)
            .onAppear { withAnimation(animated ? .spring(response: 0.65, dampingFraction: 0.68) : nil) { appeared = true } }
            .accessibilityHidden(true)
    }
}
