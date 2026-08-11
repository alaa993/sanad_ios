import Foundation

public struct TriageInsight {
    public let category: String
    public let recommendedSpecialist: String
    public let reasoning: String
}

public final class TriageEvaluator {
    public static func evaluate(intake: DashboardIntake?) -> TriageInsight? {
        guard let intake = intake else { return nil }
        if let category = intake.triage_category, !category.isEmpty {
            let reason = intake.triage_reason ?? defaultReason(for: category)
            let specialist = intake.recommended_specialist?.name ?? defaultSpecialist(for: category)
            return TriageInsight(
                category: category.capitalized,
                recommendedSpecialist: specialist,
                reasoning: reason
            )
        }

        let keywords = (intake.risk_flags ?? []).map { $0.lowercased() }
        let narrative = intake.primary_issue?.lowercased() ?? ""
        let hasMedication = containsAny(in: keywords, terms: ["medication", "دواء", "دوائي"]) ||
            narrative.contains("دواء")

        if containsAny(in: keywords, terms: ["bipolar", "ثنائي"]) || narrative.contains("ثنائي القطب") {
            return TriageInsight(
                category: "ثنائي القطب",
                recommendedSpecialist: "طبيب نفسي",
                reasoning: "تشير الأعراض إلى تقلبات بين النشوة والاكتئاب وتحتاج متابعة طبية متخصصة."
            )
        }
        if containsAny(in: keywords, terms: ["schizophrenia", "فصام"]) || narrative.contains("فصام") {
            return TriageInsight(
                category: "فصام",
                recommendedSpecialist: "طبيب نفسي",
                reasoning: "تستدعي المؤشرات المصاحبة إعادة تقييم طبي بسبب خطر انفصال الواقع."
            )
        }
        if containsAny(in: keywords, terms: ["children", "طفل", "طفولة"]) ||
            narrative.contains("طفل") || narrative.contains("طفولة") {
            return TriageInsight(
                category: "أطفال وسلوك",
                recommendedSpecialist: "أخصائي أطفال أو سلوك",
                reasoning: "يبدو أن الحالة تأتي من مرحلة الطفولة أو تحتاج تعامل خاص للأطفال."
            )
        }
        if containsAny(in: keywords, terms: ["anxiety", "depression", "قلق", "اكتئاب"]) ||
            narrative.contains("قلق") || narrative.contains("اكتئاب") {
            let specialist = hasMedication ? "طبيب نفسي" : "أخصائي علاج معرفي سلوكي"
            let reason = hasMedication
                ? "الاعتماد على دواء أو استمرار الأعراض يستدعي تقييمًا طبيًا."
                : "الأعراض النصية أو القلق المعتدل يمكن البدء في جلسات علاج معرفي."
            return TriageInsight(
                category: "قلق/اكتئاب",
                recommendedSpecialist: specialist,
                reasoning: reason
            )
        }
        if containsAny(in: keywords, terms: ["sleep", "adhd", "تركيز", "نسيان"]) ||
            narrative.contains("نوم") || narrative.contains("تركيز") {
            return TriageInsight(
                category: "دعم نفسي عام",
                recommendedSpecialist: "أخصائي نفسي",
                reasoning: "الاضطرابات في النوم أو التركيز تحتاج متابعة علاجية داعمة."
            )
        }
        if containsAny(in: keywords, terms: ["identity", "هوية"]) || narrative.contains("هوية") {
            return TriageInsight(
                category: "هوية ودعم عاطفي",
                recommendedSpecialist: "أخصائي دعم وجلسات جدلية",
                reasoning: "التحديات المرتبطة بالهوية تحتاج دعمًا عاطفيًا متخصصًا."
            )
        }
        if hasMedication || !keywords.isEmpty {
            return TriageInsight(
                category: "عام",
                recommendedSpecialist: hasMedication ? "طبيب نفسي" : "أخصائي نفسي",
                reasoning: "المؤشرات الحالية تستدعي الاستمرار بمعالج أو مراجعة طبية حسب الحاجة."
            )
        }
        return nil
    }

    private static func containsAny(in list: [String], terms: [String]) -> Bool {
        for term in terms where list.contains(where: { $0.contains(term) }) {
            return true
        }
        return false
    }

    private static func defaultSpecialist(for category: String) -> String {
        switch category.lowercased() {
        case "bipolar", "ثنائي القطب": return "طبيب نفسي"
        case "schizophrenia", "فصام": return "طبيب نفسي"
        case "children", "أطفال وسلوك": return "أخصائي أطفال/سلوك"
        case "anxiety", "depression", "قلق/اكتئاب": return "أخصائي علاج معرفي"
        default: return "أخصائي نفسي"
        }
    }

    private static func defaultReason(for category: String) -> String {
        switch category.lowercased() {
        case "bipolar", "ثنائي القطب":
            return "الأعراض تشير إلى تقلبات المزاج القوية وتحتاج تقييمًا طبيًا مباشرًا."
        case "schizophrenia", "فصام":
            return "الانفصال عن الواقع هو مؤشر يعتمد المتابعة الطبية السريعة."
        case "children", "أطفال وسلوك":
            return "الحالة مرتبطة بمرحلة الطفولة وتحتاج دعمًا متخصصًا لهذه الفئة."
        case "anxiety", "depression", "قلق/اكتئاب":
            return "ارتفاع القلق أو الاكتئاب يستحق جلسات دعم معرفي أو تقييم طبي."
        default:
            return "لم تتوفر مؤشرات خاصة، تابع التقييم مع أخصائي نفسي."
        }
    }
}
