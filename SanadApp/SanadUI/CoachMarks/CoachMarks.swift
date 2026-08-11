import SwiftUI

private struct CoachMarkAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

public struct CoachMarkStep: Identifiable {
    public let id: String
    public let title: LocalizedStringKey
    public let desc: LocalizedStringKey
    public let targetId: String

    public init(id: String, title: LocalizedStringKey, desc: LocalizedStringKey, targetId: String) {
        self.id = id
        self.title = title
        self.desc = desc
        self.targetId = targetId
    }
}

public extension View {
    func coachMarkTarget(_ id: String) -> some View {
        anchorPreference(key: CoachMarkAnchorKey.self, value: .bounds) { [id: $0] }
    }

    func coachMarks(key: String, steps: [CoachMarkStep]) -> some View {
        modifier(CoachMarksContainer(key: key, steps: steps))
    }
}

private struct CoachMarksContainer: ViewModifier {
    let key: String
    let steps: [CoachMarkStep]
    @State private var done: Bool

    init(key: String, steps: [CoachMarkStep]) {
        self.key = key
        self.steps = steps
        let storageKey = "coach_marks_\(key)_done"
        _done = State(initialValue: UserDefaults.standard.bool(forKey: storageKey))
    }

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(CoachMarkAnchorKey.self) { anchors in
            CoachMarksOverlay(anchors: anchors, steps: steps, done: doneBinding)
        }
    }

    private var doneBinding: Binding<Bool> {
        Binding(
            get: { done },
            set: { newValue in
                done = newValue
                UserDefaults.standard.set(newValue, forKey: "coach_marks_\(key)_done")
            }
        )
    }
}

private struct CoachMarksOverlay: View {
    let anchors: [String: Anchor<CGRect>]
    let steps: [CoachMarkStep]
    @Binding var done: Bool
    @State private var index: Int = 0

    var body: some View {
        if done || steps.isEmpty {
            EmptyView()
        } else {
            GeometryReader { geo in
                let step = steps[min(index, steps.count - 1)]
                let rect = anchors[step.targetId].map { geo[$0] }

                ZStack(alignment: .bottom) {
                    // Block all taps on content underneath — prevents accidental logout / shortcuts.
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())

                    if let rect = rect {
                        Path { path in
                            path.addRect(CGRect(origin: .zero, size: geo.size))
                            path.addRoundedRect(in: rect.insetBy(dx: -8, dy: -8), cornerSize: CGSize(width: 12, height: 12))
                        }
                        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)
                    } else {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }

                    coachMarkPanel(step: step)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func coachMarkPanel(step: CoachMarkStep) -> some View {
        VStack(spacing: 12) {
            Text(step.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(SanadTheme.onBg)
            Text(step.desc)
                .font(.system(size: 14))
                .foregroundColor(SanadTheme.placeholder)
                .multilineTextAlignment(.center)

            HStack {
                if index < steps.count - 1 {
                    Button("onboarding_skip") { done = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                }
                Spacer()
                Button(action: next) {
                    Text(index == steps.count - 1 ? "onboarding_start" : "onboarding_next")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.surface))
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func next() {
        if index < steps.count - 1 {
            withAnimation { index += 1 }
        } else {
            done = true
        }
    }
}
