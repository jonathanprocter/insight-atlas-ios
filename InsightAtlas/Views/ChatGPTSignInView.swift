import SwiftUI
import WebKit

/// Hosts the ChatGPT OAuth page in a WKWebView and intercepts the
/// `http://localhost:1455/auth/callback` redirect (which ASWebAuthenticationSession
/// cannot capture) to extract the authorization code.
struct ChatGPTAuthWebView: UIViewControllerRepresentable {
    let authURL: URL
    let redirectPrefix: String
    let onRedirect: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let web = WKWebView(frame: .zero)
        web.navigationDelegate = context.coordinator
        web.load(URLRequest(url: authURL))

        let host = UIViewController()
        host.view = web
        host.title = "Sign in with ChatGPT"
        host.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: context.coordinator,
            action: #selector(Coordinator.cancelTapped)
        )
        return UINavigationController(rootViewController: host)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ChatGPTAuthWebView
        init(_ parent: ChatGPTAuthWebView) { self.parent = parent }

        @objc func cancelTapped() { parent.onCancel() }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               url.absoluteString.hasPrefix(parent.redirectPrefix) {
                decisionHandler(.cancel)
                parent.onRedirect(url)
                return
            }
            decisionHandler(.allow)
        }
    }
}

/// Sheet that drives the OAuth flow end-to-end via `ChatGPTOAuthService`.
struct ChatGPTSignInSheet: View {
    @ObservedObject private var service = ChatGPTOAuthService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var authURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let authURL {
                ChatGPTAuthWebView(
                    authURL: authURL,
                    redirectPrefix: service.redirectPrefix,
                    onRedirect: { url in
                        Task {
                            do {
                                try await service.handleCallback(url: url)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    },
                    onCancel: { dismiss() }
                )
                .ignoresSafeArea()
            } else {
                ProgressView("Loading ChatGPT sign-in…")
            }
        }
        .task { authURL = service.authorizationURL() }
        .alert(
            "Sign-in failed",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
