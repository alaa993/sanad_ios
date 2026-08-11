import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboarding_done") private var onboardingDone = false
    @State private var index: Int = 0
    @State private var appear = false

    private let pages: [OnboardingPage] = [
        .init(title: "onboarding_modern_1_title", desc: "onboarding_modern_1_desc", icon: .care),
        .init(title: "onboarding_title_2", desc: "onboarding_desc_2", icon: .community),
        .init(title: "onboarding_title_3", desc: "onboarding_desc_3", icon: .sessions)
    ]

    var body: some View {
        ZStack {
            SanadAtmosphereBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("onboarding_skip") { onboardingDone = true }
                        .font(SanadFont.bodyMedium(14))
                        .foregroundColor(SanadTheme.primary)
                        .opacity(index == pages.count - 1 ? 0 : 1)
                        .padding(.top, 12)
                        .padding(.trailing, 20)
                }

                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                        VStack(spacing: 22) {
                            Spacer(minLength: 24)

                            Image(SanadTheme.logoName(background: false))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .opacity(appear ? 1 : 0)

                            ZStack {
                                Circle()
                                    .fill(SanadTheme.primary.opacity(0.10))
                                    .frame(width: 150, height: 150)
                                page.icon.view(size: 44)
                                    .foregroundColor(SanadTheme.primary)
                            }

                            Text(LocalizedStringKey(page.title))
                                .font(SanadFont.title(26))
                                .foregroundColor(SanadTheme.onBg)
                                .multilineTextAlignment(.center)

                            Text(LocalizedStringKey(page.desc))
                                .font(SanadFont.body(15))
                                .foregroundColor(SanadTheme.placeholder)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .lineSpacing(4)

                            Spacer()
                        }
                        .tag(i)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

                SanadButton(
                    title: LocalizedStringKey(index == pages.count - 1 ? "onboarding_start" : "onboarding_next"),
                    kind: .primary
                ) {
                    handleNext()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.28)) { appear = true }
        }
    }

    private func handleNext() {
        if index < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
        } else {
            onboardingDone = true
        }
    }
}

private struct OnboardingPage {
    let title: String
    let desc: String
    let icon: SanadIcon
}
