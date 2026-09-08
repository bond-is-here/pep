import SwiftUI

struct MomentumCard: View {
    let momentum: WorkoutMomentum
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(RCTheme.heroEnd)
                        .frame(width: 58, height: 58).rotationEffect(.degrees(-7))
                    Image(systemName: momentum.isEarned ? "hands.clap.fill" : "sparkles")
                        .font(.system(size: 24, weight: .semibold)).foregroundStyle(RCTheme.text)
                }.accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(momentum.isEarned ? "LOOK AT YOU GO" : "YOUR NEXT LITTLE WIN")
                        .font(.system(.caption2, design: .rounded, weight: .heavy)).tracking(1)
                        .foregroundStyle(RCTheme.accentText)
                    Text(momentum.title).font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(RCTheme.text).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            ProgressView(value: momentum.fraction).tint(RCTheme.accent)
                .animation(reduceMotion || !RCAppearance.shared.motionEnabled ? nil : .easeOut(duration: 0.4), value: momentum.fraction)
                .accessibilityHidden(true)
            HStack(alignment: .top) {
                Text(momentum.isEarned ? "\(momentum.target) saved. High five!" : "\(momentum.completedWorkouts) / \(momentum.target) workouts")
                    .font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(RCTheme.text)
                Spacer(minLength: 12)
                Text("No streak to lose.")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(RCTheme.muted)
            }
        }.padding(20)
            .background(RCTheme.heroStart.opacity(0.5), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(RCTheme.border, lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("momentum-card")
    }
}
