import SwiftUI

struct RCThemePicker: View {
    @Bindable private var appearance = RCAppearance.shared
    @Environment(\.pepReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pick your pep").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)
            ForEach(RCColorway.allCases) { colorway in
                Button {
                    RCTheme.impact()
                    withAnimation(reduceMotion || !appearance.motionEnabled ? nil : .easeInOut(duration: 0.28)) {
                        appearance.selected = colorway
                    }
                } label: {
                    paletteCard(colorway)
                }.buttonStyle(RCPressStyle())
                    .accessibilityLabel("\(colorway.title). \(colorway.subtitle)")
                    .accessibilityIdentifier("appearance.theme.\(colorway.rawValue)")
                    .accessibilityAddTraits(appearance.selected == colorway ? .isSelected : [])
            }
            Toggle(isOn: $appearance.motionEnabled) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Bring Pep to life").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)
                    Text("A wiggly buddy. A happy little high-five.").font(.system(size: 12, design: .rounded)).foregroundStyle(RCTheme.muted)
                }
            }.toggleStyle(.switch).tint(RCTheme.accent).padding(.top, 7)
                .accessibilityIdentifier("appearance.motion")
            if reduceMotion {
                Text("Your device’s Reduce Motion setting keeps Pep still.")
                    .font(.caption).foregroundStyle(RCTheme.muted)
                    .accessibilityIdentifier("appearance.reduce-motion")
            }
            if let message = appearance.saveError {
                Text(message).font(.caption).foregroundStyle(RCTheme.accentText)
            }
        }
    }

    private func paletteCard(_ colorway: RCColorway) -> some View {
        let palette = colorway.palette
        let selected = appearance.selected == colorway
        return HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color(hex: palette.heroStart))
                Image(systemName: "face.smiling.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Color(hex: palette.accent))
                    .rotationEffect(.degrees(-8))
            }.frame(width: 74, height: 80)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(colorway.title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)
                Text(colorway.subtitle).font(.system(size: 12, design: .rounded)).foregroundStyle(RCTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    ForEach([palette.background, palette.accent, palette.secondary], id: \.self) { hex in
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: hex)).frame(width: 17, height: 12)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(RCTheme.border, lineWidth: 0.5))
                    }
                }.padding(.top, 3).accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17)).foregroundStyle(selected ? RCTheme.accentText : RCTheme.border)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RCTheme.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? RCTheme.accent : RCTheme.border, lineWidth: selected ? 1.5 : 1))
    }
}
