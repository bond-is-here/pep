import SwiftUI

struct SessionDetailView: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("A LITTLE WIN, SAVED", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.8).foregroundStyle(RCTheme.accentText)
                    Text(session.routineName).font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(session.startedAt.formatted(date: .complete, time: .shortened)).font(.system(size: 12)).foregroundStyle(RCTheme.muted)
                }
                HStack(spacing: 0) {
                    FlowMetric(title: "DURATION", value: FlowFormat.duration(session.duration))
                    FlowMetric(title: "SETS DONE", value: "\(session.completedSets)")
                    FlowMetric(title: "VOLUME · \(unit.symbol.uppercased())", value: FlowFormat.number(unit.value(fromKilograms: session.volumeKG)))
                }.padding(.vertical, 22).rcSurface(padding: 0)
                FlowFieldLabel(title: "THE WORK YOU PUT IN")
                ForEach(session.exercises) { exercise in
                    if exercise.completedSets > 0 {
                        completedExercise(exercise)
                    }
                }
                Text("Volume is the sum of weight × reps for your completed sets. Bodyweight sets still count toward your set total.")
                    .font(.system(size: 11)).foregroundStyle(RCTheme.muted).lineSpacing(3)
            }.padding(22).padding(.bottom, 20)
        }
        .foregroundStyle(RCTheme.text).background(RCTheme.background.ignoresSafeArea()).preferredColorScheme(RCAppearance.shared.colorScheme)
        .navigationTitle("Workout recap").navigationBarTitleDisplayModeIfAvailable()
    }

    private func completedExercise(_ exercise: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 12) {
                Image(systemName: "dumbbell.fill").font(.system(size: 17)).foregroundStyle(RCTheme.accentText)
                Text(exercise.name).font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
            }
            HStack {
                Text("SET").frame(width: 35, alignment: .leading)
                Spacer()
                Text("WEIGHT").frame(width: 95, alignment: .trailing)
                Text("REPS").frame(width: 60, alignment: .trailing)
                Color.clear.frame(width: 26, height: 1)
            }.font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.8).foregroundStyle(RCTheme.muted)
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                if set.isComplete {
                    HStack {
                        Text("\(index + 1)").foregroundStyle(RCTheme.muted).frame(width: 35, alignment: .leading)
                        Spacer()
                        Text(set.weightKG == 0 ? "Bodyweight" : "\(FlowFormat.number(unit.value(fromKilograms: set.weightKG))) \(unit.symbol)")
                            .frame(width: 95, alignment: .trailing)
                        Text("\(set.reps)").frame(width: 60, alignment: .trailing)
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(RCTheme.accentText).frame(width: 26)
                    }.font(.system(size: 14, weight: .medium, design: .rounded)).monospacedDigit().padding(.vertical, 4)
                }
            }
        }.padding(20).rcSurface(padding: 0)
    }
}
