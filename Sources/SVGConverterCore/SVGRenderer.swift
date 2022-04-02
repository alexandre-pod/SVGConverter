//
//  SVGRenderer.swift
//  svg2png
//
//  Created by Alexandre Podlewski on 30/03/2022.
//

import Foundation
import WebKit

@available(macOS 10.15, *)
public final class SVGRenderer: WKWebView, WKNavigationDelegate {

    // MARK: - Private Types

    private enum InternalError: Error {
        case renderingAlreadyInProgress
        case invalidSVGData
        case cgImageConversionFailed
        case pngImageConversionFailed
        case invalidState
    }

    // MARK: - Private Properties

    private let allowViewBoxFix: Bool
    private let quiet: Bool
    private var completion: ((Result<Data, Error>) -> Void)?
    private var isRendering = false
    private var size: CGSize = .zero

    // MARK: - Life cycle

    public init(allowViewBoxFix: Bool = true, quiet: Bool = false) {
        self.allowViewBoxFix = allowViewBoxFix
        self.quiet = quiet
        super.init(frame: .zero, configuration: SVGRenderer.rendererConfiguration)
        navigationDelegate = self
    }

    @available(*, unavailable)
    required public init?(coder: NSCoder) {
        self.allowViewBoxFix = true
        self.quiet = false
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - SVGRenderer

    @available(*, renamed: "render(svgString:svgSize:)")
    public func render(
        svgData: Data,
        size: CGSize,
        scale: CGFloat = 1.0,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        guard !isRendering else {
            assertionFailure("SVGRenderer can only do one render at a time")
            completion(.failure(InternalError.renderingAlreadyInProgress))
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
                throw InternalError.invalidState
            }
            loadHTMLString(htmlDocument(forSVG: svgString), baseURL: nil)
        } catch {
            didComplete(with: .failure(error))
            return
        }
    }

    @available(macOS 10.15, *)
    public func render(svgData: Data,size: CGSize,scale: CGFloat = 1.0) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            render(svgData: svgData, size: size, scale: scale) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
                throw InternalError.invalidState
            }

            self.didComplete(with: snapshotResult.throwingMap { image in
                guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw InternalError.cgImageConversionFailed
                }
                let rep = NSBitmapImageRep(cgImage: cgImage)
                rep.size = self.size
                guard let data = rep.representation(using: .png, properties: [:]) else {
                    throw InternalError.pngImageConversionFailed
                }
                return data
            })
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        didComplete(with: .failure(error))
    }

    // MARK: - Private

    private func resizeSVG(_ svg: Data, to size: CGSize) throws -> Data {
        let document = try XMLDocument(data: svg)
        guard
            let svgElement = document.rootElement(),
            svgElement.name == "svg"
        else { throw InternalError.invalidSVGData }

        if svgElement.attribute(forName: "viewBox") == nil {
            if
                allowViewBoxFix,
                let width = svgElement.attribute(forName: "width")?.stringValue.flatMap(Double.init),
                let height = svgElement.attribute(forName: "height")?.stringValue.flatMap(Double.init)
            {
                printWarning("Missing viewBox in svg file, one was guessed using width and height")
                svgElement.set(value: "0 0 \(width) \(height)", for: "viewBox")
            } else {
                printWarning("Missing viewBox in svg file, the svg will not be resized")
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

    private func printWarning(_ message: String) {
        guard !quiet else { return }
        FileHandle.standardError.write(Data("[Warning] \(message)\n".utf8))
    }

    private func didComplete(with result: Result<Data, Error>) {
        let completionReference = completion
        isRendering = false
        completion = nil
        completionReference?(result)
    }
}

@available(macOS 10.15, *)
private extension SVGRenderer {

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
