//
//  WebViewSVGRenderer.swift
//
//
//  Created by Alexandre Podlewski on 02/04/2022.
//

import Foundation
import WebKit

private extension SVGRenderingWarnings {
    static let missingViewBoxAndNoDefinedSize = SVGRenderingWarnings(
        "Missing viewBox in svg file, the svg will not be resized"
    )
    static let missingViewBoxAndComputedFromSize = SVGRenderingWarnings(
        "Missing viewBox in svg file, one was guessed using width and height"
    )
}

@available(macOS 10.15, *)
final class WebViewSVGRenderer: WKWebView, WKNavigationDelegate {

    // MARK: - Public typealias

    typealias WarningHandler = (SVGRenderingWarnings) -> Void

    // MARK: - Public properties

    var warningHandler: WarningHandler?

    // MARK: - Private Properties

    private let allowFixingMissingViewBox: Bool
    private var completion: ((Result<Data, Error>) -> Void)?
    private var isRendering = false
    private var size: CGSize = .zero

    // MARK: - Life cycle

    /// An SVG renderer using a WebView to render the SVG
    /// - Parameter allowFixingMissingViewBox: allow the renderer to try adding a viewBox attribute to svg that are lacking of it.
    /// Without viewBox the renderer is unable to resize the svg image.
    init(allowFixingMissingViewBox: Bool = true) {
        self.allowFixingMissingViewBox = allowFixingMissingViewBox
        super.init(frame: .zero, configuration: WebViewSVGRenderer.rendererConfiguration)
        navigationDelegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        self.allowFixingMissingViewBox = true
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - SVGRenderer

    @available(*, renamed: "render(svgString:svgSize:)")
    func render(
        svgData: Data,
        size: CGSize,
        scale: CGFloat = 1.0,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        guard !isRendering else {
            assertionFailure("SVGRenderer can only do one render at a time")
            completion(.failure(SVGRenderingError.renderingAlreadyInProgress))
            return
        }
        isRendering = true
        self.completion = completion
        let webViewScale = layer?.contentsScale ?? 1
        self.size = NSSize(
            width: scale * size.width / webViewScale,
            height: scale * size.height / webViewScale
        )
        do {
            let resizedSVGData = try resizeSVG(svgData, to: self.size)
            guard let svgString = String(data: resizedSVGData, encoding: .utf8) else {
                throw SVGRenderingError.invalidState
            }
            loadHTMLString(htmlDocument(forSVG: svgString), baseURL: nil)
        } catch {
            didComplete(with: .failure(error))
            return
        }
    }

    @available(macOS 10.15, *)
    func render(svgData: Data, size: CGSize, scale: CGFloat = 1.0) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            render(svgData: svgData, size: size, scale: scale) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = true
        config.rect = NSRect(origin: .zero, size: size)

        webView.frame.size = size
        webView.takeSnapshot(with: config) { [weak self] image, error in
            guard let self = self else { return }
            let snapshotResult = Result<NSImage, Error> {
                if let error = error {
                    throw error
                }
                if let image = image {
                    return image
                }
                throw SVGRenderingError.invalidState
            }

            self.didComplete(with: snapshotResult.throwingMap { image in
                guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw SVGRenderingError.cgImageConversionFailed
                }
                let rep = NSBitmapImageRep(cgImage: cgImage)
                rep.size = self.size
                guard let data = rep.representation(using: .png, properties: [:]) else {
                    throw SVGRenderingError.pngImageConversionFailed
                }
                return data
            })
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        didComplete(with: .failure(error))
    }

    // MARK: - Private

    private func resizeSVG(_ svg: Data, to size: CGSize) throws -> Data {
        let document = try XMLDocument(data: svg)
        guard
            let svgElement = document.rootElement(),
            svgElement.name == "svg"
        else { throw SVGRenderingError.invalidSVGData }

        if svgElement.attribute(forName: "viewBox") == nil {
            if
                allowFixingMissingViewBox,
                let width = svgElement.attribute(forName: "width")?.stringValue.flatMap(Double.init),
                let height = svgElement.attribute(forName: "height")?.stringValue.flatMap(Double.init)
            {
                warningHandler?(.missingViewBoxAndComputedFromSize)
                svgElement.set(value: "0 0 \(width) \(height)", for: "viewBox")
            } else {
                warningHandler?(.missingViewBoxAndNoDefinedSize)
            }
        }

        svgElement.set(value: "\(size.width)", for: "width")
        svgElement.set(value: "\(size.height)", for: "height")
        return document.xmlData()
    }

    private func htmlDocument(forSVG svg: String) -> String {
        return """
        <html>
        <head><style>*{margin:0;}</style></head>
        <body>\(svg)</body>
        </html>
        """
    }

    private func didComplete(with result: Result<Data, Error>) {
        let completionReference = completion
        isRendering = false
        completion = nil
        completionReference?(result)
    }
}

@available(macOS 10.15, *)
private extension WebViewSVGRenderer {

    static let rendererConfiguration: WKWebViewConfiguration = {
        let pagePreference = WKWebpagePreferences()
        let configuration = WKWebViewConfiguration()
        if #available(macOS 11.0, *) {
            pagePreference.allowsContentJavaScript = false
        } else {
            configuration.preferences.javaScriptEnabled = false
        }
        configuration.defaultWebpagePreferences = pagePreference
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = true
        return configuration
    }()
}
