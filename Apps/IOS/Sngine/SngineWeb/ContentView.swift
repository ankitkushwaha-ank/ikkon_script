import SwiftUI
import WebKit
import OneSignalFramework

struct ContentView: View {
    let urlString: String = "https://demo.sngine.com/"
    
    var body: some View {
        WebView(url: URL(string: urlString)!)
    }
}

struct WebView: UIViewRepresentable {
    var url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator // Set the navigation delegate
        webView.configuration.allowsInlineMediaPlayback = true

        // Add refresh control to the WKWebView's scroll view
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefreshControl(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        // Handle refresh control action
        @objc func handleRefreshControl(_ refreshControl: UIRefreshControl) {
            refreshControl.beginRefreshing()
            parent.url = URL(string: parent.url.absoluteString)!
            let request = URLRequest(url: parent.url)
            if let webView = refreshControl.superview?.superview as? WKWebView {
                webView.load(request)
                refreshControl.endRefreshing()
            }
        }

        // Handle navigation actions
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated {
                // Check if the link is internal or external
                if isInternalLink(url) {
                    // Open internal links in the web-view
                    decisionHandler(.allow)
                } else {
                    // Open external links in Safari
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Ensure DOM is ready before injecting JavaScript
            webView.evaluateJavaScript("document.readyState", completionHandler: { (result, error) in
                guard let readyState = result as? String, readyState == "complete" else {
                    print("Error checking document readiness: \(error?.localizedDescription ?? "")")
                    return
                }

                // Handle OneSignal user ID
                if let oneSignalUserId = AppDelegate.oneSignalUserId, !oneSignalUserId.isEmpty {
                    let js = "saveIOSOneSignalUserId('\(oneSignalUserId)')"
                    webView.evaluateJavaScript(js) { (result, error) in
                        if let error = error {
                            print("Error injecting JavaScript: \(error.localizedDescription)")
                            // Handle error, e.g., retry, log, display alert
                        } else {
                            print("JavaScript injected successfully")
                        }
                    }
                } else {
                    print("OneSignal user ID is nil or empty")
                    // Handle empty user ID, e.g., log warning, provide default value
                }
            })
        }

        // Check if the link is internal (belonging to the same host as the original URL)
        private func isInternalLink(_ url: URL) -> Bool {
            return url.host == parent.url.host
        }
    }
}
