//
//  SVGRenderer.swift
//  svg2png
//
//  Created by Alexandre Podlewski on 30/03/2022.
//

import Foundation
import AppKit

@available(macOS 10.15, *)
@MainActor
public final class SVGRenderer {

    // MARK: - Public typealiases

    public typealias WarningHandler = (SVGRenderingWarnings) -> Void

    // MARK: - Public structures

    public struct Configuration {

        /// Controls wether or not the renderer will try to add viewBox attribute to SVG without one
        ///
        /// When at true, if there is no viewBox attribute in the SVG and the svg has a width and an height, it will add a viewBox attribute with the value `"0 0 width height"`
        public var allowFixingMissingViewBox: Bool

        /// When this is true the renderer will produce an image without alpha channel
        public var removePNGAlphaChannel: Bool

        /// Create a configuration for SVGRenderer
        /// - Parameter allowFixingMissingViewBox: Controls wether or not the renderer will try to add viewBox attribute to SVG without one
        public init(
            allowFixingMissingViewBox: Bool = true,
            removePNGAlphaChannel: Bool = false
        ) {
            self.allowFixingMissingViewBox = allowFixingMissingViewBox
            self.removePNGAlphaChannel = removePNGAlphaChannel
        }
    }

    // MARK: - Public properties

    /// Receives warnings detected by the renderer. Set it to `nil` to ignore those warnings
    ///
    /// By default to `nil`
    public var warningHandler: WarningHandler? = nil {
        didSet {
            self.renderer.warningHandler = warningHandler
        }
    }

    // MARK: - Private Properties

    private let rendererWindow: NSWindow
    private let renderer: WebViewSVGRenderer

    // MARK: - Life cycle

    @MainActor
    public init(
        configuration: Configuration = Configuration(),
        warningHandler: WarningHandler? = nil
    ) {

        var options: WebViewSVGRenderer.Options = []
        if !configuration.allowFixingMissingViewBox {
            options.insert(.preventViewBoxFix)
        }
        if configuration.removePNGAlphaChannel {
            options.insert(.removePNGAlphaChannel)
        }
        self.renderer = WebViewSVGRenderer(options: options)

        // ???: (Alexandre Podlewski) 09/04/2022 Without forcing the backing scale factor it is not possible to control
        //      the output of screeshoting the web view. Without window issues could also occurred when changing of
        //      focused screen with a different scale factor. An issue occurred when focused on a x1 screen, with
        //      the webview outside of a window it had a default backing scale factor of x2 but the snapshot was taken
        //      as x1, this causing invalid size generated images.
        self.rendererWindow = PixelScaleWindow()
        self.rendererWindow.contentView = self.renderer

        self.warningHandler = warningHandler
        self.renderer.warningHandler = warningHandler
    }

    // MARK: - SVGRenderer

    /// Transform SVG Data to PNG data
    /// - Parameters:
    ///   - svgData: The SVG data to render
    ///   - size: The size in pixel of the PNG returned by this method
    ///   - completion: The completion handler returning the rendered PNG or an error
    public func render(
        svgData: Data,
        size: CGSize,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        renderer.render(svgData: svgData, size: size, completion: completion)
    }

    /// Transform SVG Data to PNG data
    /// - Parameters:
    ///   - svgData: The SVG data to render
    ///   - size: The size in pixel of the PNG returned by this method
    @available(macOS 10.15, *)
    public func render(svgData: Data, size: CGSize) async throws -> Data {
        return try await renderer.render(svgData: svgData, size: size)
    }
}
