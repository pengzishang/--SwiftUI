import SwiftUI
import UIKit

/// Keeps the system navigation controller's interactive edge-swipe pop gesture enabled.
///
/// The gesture remains owned by UIKit, so it preserves the native transition progress,
/// cancellation behavior, and conflict handling with lists, web content, and scrolling.
struct InteractiveSwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ObserverViewController {
        ObserverViewController()
    }

    func updateUIViewController(_ uiViewController: ObserverViewController, context: Context) {
        uiViewController.enableInteractiveSwipeBackWhenPossible()
    }

    final class ObserverViewController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            enableInteractiveSwipeBackWhenPossible()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            enableInteractiveSwipeBackWhenPossible()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enableInteractiveSwipeBackWhenPossible()
        }

        func enableInteractiveSwipeBackWhenPossible() {
            DispatchQueue.main.async { [weak self] in
                guard let navigationController = self?.navigationController,
                      navigationController.viewControllers.count > 1 else {
                    return
                }
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
            }
        }
    }
}

extension View {
    /// Enables the native left-edge swipe gesture for returning to the previous page.
    func enablesInteractiveSwipeBack() -> some View {
        background {
            InteractiveSwipeBackEnabler()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}
