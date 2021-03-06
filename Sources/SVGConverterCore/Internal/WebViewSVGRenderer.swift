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

    // MARK: - Public structures

    struct Options: OptionSet {
        let rawValue: Int

        /// This option stop the renderer to try adding a viewBox attribute to svg that are lacking of it. Without viewBox the renderer is unable to resize the svg image.
        static let preventViewBoxFix = Options(rawValue: 1<<0)
        /// Tells the renderer to remove the alpha channel from the PNG image data
        static let removePNGAlphaChannel = Options(rawValue: 1<<1)
    }

    // MARK: - Public typealias

    typealias WarningHandler = (SVGRenderingWarnings) -> Void

    // MARK: - Public properties

    var warningHandler: WarningHandler?

    // MARK: - Private Properties

    private let options: Options
    private var completion: ((Result<Data, Error>) -> Void)?
    private var isRendering = false
    private var inPixelSize: CGSize = .zero
    private var inPointSize: CGSize = .zero

    // MARK: - Life cycle

    /// An SVG renderer using a WebView to render the SVG
    /// - Parameter allowFixingMissingViewBox: allow the renderer to try adding a viewBox attribute to svg that are lacking of it.
    /// Without viewBox the renderer is unable to resize the svg image.
    init(options: Options = []) {
        self.options = options
        super.init(frame: .zero, configuration: WebViewSVGRenderer.rendererConfiguration)
        navigationDelegate = self
        setValue(false, forKey: "drawsBackground")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        self.options = []
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - SVGRenderer

    func render(
        svgData: Data,
        size: CGSize,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        guard !isRendering else {
            assertionFailure("SVGRenderer can only do one render at a time")
            completion(.failure(SVGRenderingError.renderingAlreadyInProgress))
            return
        }
        isRendering = true
        self.completion = completion
        self.inPixelSize = size
        self.inPointSize = self.convertFromBacking(size)
        do {
            let resizedSVGData = try resizeSVG(svgData, to: self.inPointSize)
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
    func render(svgData: Data, size: CGSize) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            render(svgData: svgData, size: size) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = true
        config.rect = NSRect(
            origin: .zero,
            size: NSSize(
                width: inPointSize.width.rounded(.up),
                height: inPointSize.height.rounded(.up)
            )
        )

        webView.frame.size = config.rect.size
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
                guard
                    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                    let resizedCGImage = cgImage.cropping(to: CGRect(origin: .zero, size: self.inPixelSize))
                else {
                    throw SVGRenderingError.cgImageConversionFailed
                }
                let rep: NSBitmapImageRep
                if self.options.contains(.removePNGAlphaChannel) {
                    guard let transformedImage = resizedCGImage.removingAlphaChannel() else {
                        throw SVGRenderingError.alphaChannelRemovalFailed
                    }
                    rep = NSBitmapImageRep(cgImage: transformedImage)
                } else {
                    rep = NSBitmapImageRep(cgImage: resizedCGImage)
                }
                rep.size = self.inPixelSize
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
                !options.contains(.preventViewBoxFix),
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
