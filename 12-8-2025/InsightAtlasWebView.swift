import UIKit
import WebKit

/// iOS WebView implementation for Insight Atlas 2026 Edition
/// Fixes rendering issues with HTML/CSS content on iPad/iPhone
class InsightAtlasWebView: WKWebView {
    
    // MARK: - Initialization
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        // Configure WebView for optimal rendering
        let config = configuration
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
        
        // Enable viewport meta tag support
        if #available(iOS 13.0, *) {
            config.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        
        super.init(frame: frame, configuration: config)
        
        setupWebView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }
    
    // MARK: - Setup
    
    private func setupWebView() {
        // Enable scrolling
        scrollView.isScrollEnabled = true
        scrollView.bounces = true
        
        // Disable zoom (optional - remove if you want pinch-to-zoom)
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        
        // Background color
        backgroundColor = UIColor(red: 250/255, green: 249/255, blue: 247/255, alpha: 1.0) // Cream
        isOpaque = false
        
        // Enable hardware acceleration
        layer.shouldRasterize = false
        
        // Configure content mode
        contentMode = .scaleToFill
        
        // Allow link preview
        allowsLinkPreview = true
    }
    
    // MARK: - Load HTML with Fixes
    
    /// Load HTML content with iOS-specific fixes applied
    /// - Parameters:
    ///   - htmlContent: The HTML content to display
    ///   - baseURL: Optional base URL for loading resources
    func loadInsightAtlasContent(_ htmlContent: String, baseURL: URL? = nil) {
        // Inject iOS-specific CSS fixes
        let fixedHTML = injectIOSFixes(into: htmlContent)
        
        // Load the content
        loadHTMLString(fixedHTML, baseURL: baseURL)
    }
    
    /// Inject iOS-specific CSS fixes into HTML content
    private func injectIOSFixes(into html: String) -> String {
        // iOS-specific CSS fixes
        let iosFixes = """
        <style>
        /* iOS WebView Specific Fixes */
        
        /* Fix 1: Prevent thick black lines on dividers */
        .section-divider-ornament {
            border: none !important;
            height: auto !important;
            min-height: 20px !important;
            display: block !important;
        }
        
        .section-divider-ornament::before {
            content: '◆ ◇ ◆' !important;
            display: block !important;
            font-size: 14px !important;
            color: #C9A227 !important;
            text-align: center !important;
            letter-spacing: 0.5em !important;
            font-family: -apple-system, Arial, sans-serif !important;
        }
        
        /* Fix 2: Prevent text truncation in lists */
        .action-box ol li {
            padding-left: 3rem !important;
            overflow: visible !important;
        }
        
        ol li {
            padding-left: 2rem !important;
            overflow: visible !important;
        }
        
        /* Fix 3: Ensure proper box rendering */
        .insight-note,
        .quick-glance,
        .action-box,
        .exercise,
        .takeaways,
        .foundational-narrative {
            display: block !important;
            width: 100% !important;
            box-sizing: border-box !important;
            -webkit-transform: translateZ(0) !important;
        }
        
        /* Fix 4: Font rendering */
        body {
            -webkit-font-smoothing: antialiased !important;
            -moz-osx-font-smoothing: grayscale !important;
        }
        
        /* Fix 5: Prevent border rendering issues */
        * {
            -webkit-box-sizing: border-box !important;
            box-sizing: border-box !important;
        }
        
        /* Fix 6: Ensure viewport is properly set */
        html {
            -webkit-text-size-adjust: 100% !important;
        }
        
        /* Fix 7: Improve touch targets */
        a, button {
            min-height: 44px !important;
            min-width: 44px !important;
        }
        </style>
        """
        
        // Check if HTML already has a head tag
        if html.contains("</head>") {
            // Insert before closing head tag
            return html.replacingOccurrences(of: "</head>", with: "\(iosFixes)</head>")
        } else if html.contains("<head>") {
            // Insert after opening head tag
            return html.replacingOccurrences(of: "<head>", with: "<head>\(iosFixes)")
        } else {
            // No head tag, wrap content
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                \(iosFixes)
            </head>
            <body>
                \(html)
            </body>
            </html>
            """
        }
    }
    
    // MARK: - Export Functions
    
    /// Export the current content as PDF
    func exportAsPDF(completion: @escaping (Data?) -> Void) {
        let config = WKPDFConfiguration()
        config.rect = bounds
        
        createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                completion(data)
            case .failure(let error):
                print("PDF export failed: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    /// Export the current content as HTML
    func exportAsHTML(completion: @escaping (String?) -> Void) {
        evaluateJavaScript("document.documentElement.outerHTML") { result, error in
            if let error = error {
                print("HTML export failed: \(error.localizedDescription)")
                completion(nil)
            } else if let html = result as? String {
                completion(html)
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - View Controller Example

/// Example View Controller showing how to use InsightAtlasWebView
class InsightAtlasViewController: UIViewController {
    
    private var webView: InsightAtlasWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupWebView()
        loadContent()
    }
    
    private func setupWebView() {
        // Create WebView configuration
        let config = WKWebViewConfiguration()
        
        // Create WebView
        webView = InsightAtlasWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add to view
        view.addSubview(webView)
    }
    
    private func loadContent() {
        // Example: Load HTML file from bundle
        if let htmlPath = Bundle.main.path(forResource: "StrongGround-InsightAtlasGuide", ofType: "html"),
           let htmlContent = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            
            // Load with iOS fixes applied
            webView.loadInsightAtlasContent(htmlContent, baseURL: URL(fileURLWithPath: htmlPath))
        }
        
        // Or load from URL
        // if let url = URL(string: "https://example.com/guide.html") {
        //     let request = URLRequest(url: url)
        //     webView.load(request)
        // }
    }
    
    // MARK: - Export Actions
    
    @IBAction func exportAsPDF(_ sender: Any) {
        webView.exportAsPDF { pdfData in
            guard let data = pdfData else {
                print("Failed to export PDF")
                return
            }
            
            // Save or share PDF
            let fileName = "InsightAtlas-\(Date().timeIntervalSince1970).pdf"
            self.savePDF(data: data, fileName: fileName)
        }
    }
    
    @IBAction func exportAsHTML(_ sender: Any) {
        webView.exportAsHTML { htmlContent in
            guard let html = htmlContent else {
                print("Failed to export HTML")
                return
            }
            
            // Save or share HTML
            let fileName = "InsightAtlas-\(Date().timeIntervalSince1970).html"
            self.saveHTML(content: html, fileName: fileName)
        }
    }
    
    // MARK: - Helper Methods
    
    private func savePDF(data: Data, fileName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let pdfPath = documentsPath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: pdfPath)
            print("PDF saved to: \(pdfPath)")
            
            // Share the PDF
            sharePDF(at: pdfPath)
        } catch {
            print("Error saving PDF: \(error.localizedDescription)")
        }
    }
    
    private func saveHTML(content: String, fileName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let htmlPath = documentsPath.appendingPathComponent(fileName)
        
        do {
            try content.write(to: htmlPath, atomically: true, encoding: .utf8)
            print("HTML saved to: \(htmlPath)")
            
            // Share the HTML
            shareHTML(at: htmlPath)
        } catch {
            print("Error saving HTML: \(error.localizedDescription)")
        }
    }
    
    private func sharePDF(at url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    private func shareHTML(at url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
}

// MARK: - Extensions

extension InsightAtlasWebView: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Content loaded successfully")
        
        // Optional: Inject additional JavaScript if needed
        let js = """
        // Additional JavaScript fixes if needed
        console.log('Insight Atlas content loaded');
        """
        evaluateJavaScript(js, completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Navigation failed: \(error.localizedDescription)")
    }
}
