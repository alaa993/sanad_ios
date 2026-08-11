import SwiftUI

#if canImport(UIKit)
import UIKit

private final class KeyboardDismissTapDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view else { return true }
        var current: UIView? = view
        while let candidate = current {
            if candidate is UITextField || candidate is UITextView {
                return false
            }
            current = candidate.superview
        }
        return true
    }
}

private struct KeyboardDismissGestureView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(KeyboardDismissCoordinator.handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator.delegate
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> KeyboardDismissCoordinator {
        KeyboardDismissCoordinator()
    }
}

private final class KeyboardDismissCoordinator: NSObject {
    let delegate = KeyboardDismissTapDelegate()

    @objc func handleTap() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        background(KeyboardDismissGestureView())
    }
}
#else
extension View {
    func dismissKeyboardOnTap() -> some View { self }
}
#endif
