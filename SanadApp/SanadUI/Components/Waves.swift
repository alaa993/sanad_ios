import SwiftUI



struct HeaderWave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveHeight = rect.height * 0.44
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: waveHeight))
        path.addCurve(
            to: CGPoint(x: 0, y: waveHeight + (rect.height - waveHeight) * 0.3),
            control1: CGPoint(x: rect.width * 0.75, y: waveHeight + 12),
            control2: CGPoint(x: rect.width * 0.25, y: waveHeight + 24)
        )
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}
struct TopWave: View {
    var color: Color = SanadTheme.primary // نفس لون Android

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                // viewport in Android
                let vw: CGFloat = 175.73
                let vh: CGFloat = 93.17

                // scale funcs
                func sx(_ x: CGFloat) -> CGFloat { (x / vw) * w }
                func sy(_ y: CGFloat) -> CGFloat { (y / vh) * h }

                // ===== Android pathData (1:1) =====
                // M175.73,0
                path.move(to: CGPoint(x: sx(175.73), y: sy(0)))

                // v40.84  ==> (175.73,40.84)
                path.addLine(to: CGPoint(x: sx(175.73), y: sy(40.84)))

                // c0,14.45 -11.71,26.16 -26.17,26.16
                // relative cubic from current point:
                // current = (175.73,40.84)
                // control1 = (175.73,55.29)
                // control2 = (164.02,67.00)
                // end      = (149.56,67.00)
                path.addCurve(
                    to: CGPoint(x: sx(149.56), y: sy(67.00)),
                    control1: CGPoint(x: sx(175.73), y: sy(55.29)),
                    control2: CGPoint(x: sx(164.02), y: sy(67.00))
                )

                // H26.16 ==> (26.16,67)
                path.addLine(to: CGPoint(x: sx(26.16), y: sy(67.00)))

                // C11.71,67 0,78.72 0,93.17
                path.addCurve(
                    to: CGPoint(x: sx(0), y: sy(93.17)),
                    control1: CGPoint(x: sx(11.71), y: sy(67.00)),
                    control2: CGPoint(x: sx(0), y: sy(78.72))
                )

                // V0 ==> (0,0)
                path.addLine(to: CGPoint(x: sx(0), y: sy(0)))

                // C0,0 11.71,0 26.16,0
                // (curve صفري على y=0 لكنه موجود في الأصل)
                path.addCurve(
                    to: CGPoint(x: sx(26.16), y: sy(0)),
                    control1: CGPoint(x: sx(0), y: sy(0)),
                    control2: CGPoint(x: sx(11.71), y: sy(0))
                )

                // h123.4 ==> end x = 26.16 + 123.4 = 149.56
                path.addLine(to: CGPoint(x: sx(149.56), y: sy(0)))

                // c14.46,0 26.17,0 26.17,0
                // curve صفري (نهاية x=175.73)
                path.addCurve(
                    to: CGPoint(x: sx(175.73), y: sy(0)),
                    control1: CGPoint(x: sx(164.02), y: sy(0)),
                    control2: CGPoint(x: sx(175.73), y: sy(0))
                )

                // Z (close)
                path.closeSubpath()
                // ==================================
            }
            .fill(color)
        }
    }
}


struct BottomWave: View {

    // استخدم Theme primary
    var color: Color = SanadTheme.primary

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                // viewport Android
                let vw: CGFloat = 175.73
                let vh: CGFloat = 79.84

                func sx(_ x: CGFloat) -> CGFloat { (x / vw) * w }
                func sy(_ y: CGFloat) -> CGFloat { (y / vh) * h }

                // ===== Android pathData (converted 1:1) =====
                // M175.73,0
                path.move(to: CGPoint(x: sx(175.73), y: sy(0)))

                // v53.67
                path.addLine(to: CGPoint(x: sx(175.73), y: sy(53.67)))

                // c0,14.45 -11.71,26.17 -26.17,26.17
                // ⚠️ ملاحظة: في ملفك موجود 1000 بدل 14.45 (خطأ واضح)
                // current = (175.73,53.67)
                // control1 = (175.73,68.12)
                // control2 = (164.02,79.84)
                // end      = (149.56,79.84)
                path.addCurve(
                    to: CGPoint(x: sx(149.56), y: sy(79.84)),
                    control1: CGPoint(x: sx(175.73), y: sy(68.12)),
                    control2: CGPoint(x: sx(164.02), y: sy(79.84))
                )

                // H26.16
                path.addLine(to: CGPoint(x: sx(26.16), y: sy(79.84)))

                // c-155.45,0 -26.16,-11.71 -26.16,-26.17
                // هنا أيضاً الأرقام في ملف Android عندك غير منطقية (155.45 أكبر من العرض)
                // لكن سأحافظ على منطق الشكل المتوقع: نزول تدريجي للزاوية اليسار للأسفل
                //
                // الأفضل (والمنطقي) هو:
                // c-14.45,0 -26.16,-11.71 -26.16,-26.17
                //
                // لذلك سأطبّق المنطق الصحيح:
                // current = (26.16,79.84)
                // control1 = (11.71,79.84)
                // control2 = (0,68.13)
                // end      = (0,53.67)
                path.addCurve(
                    to: CGPoint(x: sx(0), y: sy(53.67)),
                    control1: CGPoint(x: sx(11.71), y: sy(79.84)),
                    control2: CGPoint(x: sx(0), y: sy(68.13))
                )

                // v-1.34  => (0,52.33)
                path.addLine(to: CGPoint(x: sx(0), y: sy(52.33)))

                // c0,-14.45 11.71,-26.17 26.16,-26.17
                // end => (26.16,26.16)
                // current = (0,52.33)
                // control1 = (0,37.88)
                // control2 = (11.71,26.16)
                // end      = (26.16,26.16)
                path.addCurve(
                    to: CGPoint(x: sx(26.16), y: sy(26.16)),
                    control1: CGPoint(x: sx(0), y: sy(37.88)),
                    control2: CGPoint(x: sx(11.71), y: sy(26.16))
                )

                // h123.4 => x=149.56
                path.addLine(to: CGPoint(x: sx(149.56), y: sy(26.16)))

                // c14.46,0 26.17,-11.71 26.17,-26.16
                // end => (175.73,0)
                // current = (149.56,26.16)
                // control1 = (164.02,26.16)
                // control2 = (175.73,14.45)
                // end      = (175.73,0)
                path.addCurve(
                    to: CGPoint(x: sx(175.73), y: sy(0)),
                    control1: CGPoint(x: sx(164.02), y: sy(26.16)),
                    control2: CGPoint(x: sx(175.73), y: sy(14.45))
                )

                // Z
                path.closeSubpath()
                // ===========================================
            }
            .fill(color)
        }
    }
}
