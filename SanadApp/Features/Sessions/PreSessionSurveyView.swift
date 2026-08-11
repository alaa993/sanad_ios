import SwiftUI

struct PreSessionSurveyView: View {
    var onCompleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue
    @State private var questions: [PreSessionQuestion] = []
    @State private var answers: [String: String] = [:]
    @State private var loading = true
    @State private var submitting = false
    @State private var error: String?

    private let service = PreSessionSurveyService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SanadHeroHeader(title: "pre_session_survey_title", subtitle: "pre_session_survey_subtitle")

                    VStack(alignment: .leading, spacing: 14) {
                        if loading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if questions.isEmpty {
                            Text("pre_session_survey_empty")
                                .font(.system(size: 13))
                                .foregroundColor(SanadTheme.placeholder)
                        } else {
                            SanadListCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(questions) { question in
                                        questionField(question)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let error {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(SanadTheme.error)
                        }

                        Button("pre_session_survey_submit") {
                            Task { await submit() }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(SanadTheme.primary))
                        .foregroundColor(SanadTheme.onPrimary)
                        .disabled(submitting || loading || questions.isEmpty)
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
        .task { await load() }
    }

    @ViewBuilder
    private func questionField(_ question: PreSessionQuestion) -> some View {
        let label = question.label(for: appLanguage)
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)

            switch question.type ?? "text" {
            case "scale":
                Picker(label, selection: binding(for: question.id, default: "5")) {
                    ForEach(1..<11) { value in
                        Text("\(value)").tag("\(value)")
                    }
                }
                .pickerStyle(.segmented)
            case "boolean":
                Picker(label, selection: binding(for: question.id, default: "yes")) {
                    Text("common_yes").tag("yes")
                    Text("common_no").tag("no")
                }
                .pickerStyle(.segmented)
            default:
                TextField("pre_session_survey_answer_hint", text: textBinding(for: question.id), axis: .vertical)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(SanadTheme.fieldStroke))
            }
        }
    }

    private func binding(for key: String, default defaultValue: String) -> Binding<String> {
        Binding(
            get: { answers[key] ?? defaultValue },
            set: { answers[key] = $0 }
        )
    }

    private func textBinding(for key: String) -> Binding<String> {
        Binding(
            get: { answers[key] ?? "" },
            set: { answers[key] = $0 }
        )
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            loading = false
            return
        }
        loading = true
        defer { loading = false }
        do {
            let response = try await service.fetch(token: token)
            await MainActor.run {
                questions = response.questions ?? []
                if let existing = response.answers {
                    answers = existing
                } else {
                    for q in questions {
                        if answers[q.id] == nil {
                            switch q.type {
                            case "scale": answers[q.id] = "5"
                            case "boolean": answers[q.id] = "yes"
                            default: answers[q.id] = ""
                            }
                        }
                    }
                }
                error = nil
            }
        } catch {
            await MainActor.run {
                self.error = NSLocalizedString("pre_session_survey_load_failed", comment: "")
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
            _ = try await service.submit(answers: answers, token: token)
            onCompleted?()
            dismiss()
        } catch {
            self.error = NSLocalizedString("pre_session_survey_failed", comment: "")
        }
    }
}
