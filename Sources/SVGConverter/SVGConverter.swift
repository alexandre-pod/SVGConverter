//
//  SVGConverter.swift
//
//
//  Created by Alexandre Podlewski on 02/04/2022.
//

import Foundation
import ArgumentParser
import SVGConverterCore

@main
@available(macOS 10.15, *)
struct SVGConverter: AsyncParsableCommand {

    @Argument(help: "Path to the svg file you want to convert", transform: URL.init(fileURLWithPath:))
    var inputPath: URL

    @Argument(help: "Destination path for the created png", transform: URL.init(fileURLWithPath:))
    var outputPath: URL

    @Argument(help: "Width of the output image")
    var width: Double

    @Argument(help: "Height of the output image")
    var height: Double

    @Flag(name: .customLong("no-svg-fix"), help: "Set this to true if you do not want this tool to automatically add a viewBox attribute if it is possible. Without viewBox the svg cannot be resized, but it can still be converted at its natural size")
    var preventMissingViewBoxFix: Bool = false

    @Flag(help: "Setting this to true prevent any output in standard error output")
    var quiet: Bool = false

    func run() async throws {
        let svgData = try Data(contentsOf: inputPath)
        let configuration = SVGRenderer.Configuration(allowFixingMissingViewBox: !preventMissingViewBoxFix)
        let renderer = await SVGRenderer(
            configuration: configuration,
            warningHandler: quiet ? nil : logWarning
        )
        let pngData = try await renderer.render(svgData: svgData, size: CGSize(width: width, height: height))
        try pngData.write(to: outputPath)
    }
}

func logWarning(_ warning: SVGRenderingWarnings) {
    FileHandle.standardError.write(Data("[Warning] \(warning.localizedDescription)\n".utf8))
}
