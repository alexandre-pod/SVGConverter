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

    func run() async throws {
        let svgData = try Data(contentsOf: inputPath)
        let pngData = try await SVGRenderer().render(svgData: svgData, size: CGSize(width: width, height: height))
        try pngData.write(to: outputPath)
    }
}
