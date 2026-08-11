import SwiftUI

struct PostSessionSurveyView: View {
    let sessionId: Int
    var onSubmitted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var score = 5
    @State private var comment = ""
    @State private var submitting = false
    @State private var error: String?

    private let actions = SessionActionsService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SanadHeroHeader(title: "post_session_survey_title", subtitle: "session_detail_rating_notes_optional")

                    VStack(alignment: .leading, spacing: 14) {
                        SanadListCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("session_detail_rating")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(SanadTheme.placeholder)

                                Picker("session_detail_rating", selection: $score) {
                                    ForEach(1..<6) { value in
                                        Text("\(value)").tag(value)
                                    }
                                }
                                .pickerStyle(.segmented)

                                TextField("session_detail_rating_notes_optional", text: $comment, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(SanadTheme.surfaceAlt)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(SanadTheme.fieldStroke, lineWidth: 1)
                                    )

                                if let error {
                                    Text(error)
                                        .foregroundColor(SanadTheme.error)
                                        .font(.system(size: 13))
                                }

                                Button("common_send") { Task { await submit() } }
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(SanadTheme.primary))
                                    .foregroundColor(SanadTheme.onPrimary)
                                    .disabled(submitting)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            .background(SanadTheme.surface.ignoresSafeArea())
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        submitting = true
        defer { submitting = false }
        do {
            try await actions.submitSurvey(sessionId: sessionId, score: score, comment: comment, token: token)
            onSubmitted?()
            dismiss()
        } catch {
            self.error = NSLocalizedString("post_session_survey_failed", comment: "")
        }
    }
}
