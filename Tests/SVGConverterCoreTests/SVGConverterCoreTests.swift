import XCTest
import SnapshotTesting

import SVGConverterCore

final class SVGConverterCoreTests: XCTestCase {

    private var renderer: SVGRenderer!

    override func setUp() async throws {
        renderer = await SVGRenderer(warningHandler: nil)
    }

    func testSimpleSVGWithMultipleOfTwoSize() async throws {

        let svgData = try loadSVGData(for: "input_files/simple100x100")

        let pngData = try await renderer.render(svgData: svgData, size: CGSize(width: 10, height: 10))

        assertPNGSnapshot(matching: pngData, as: .image)
    }

    func testSimpleSVGWithOddSize() async throws {

        let svgData = try loadSVGData(for: "input_files/simple3x3")

        let pngData = try await renderer.render(svgData: svgData, size: CGSize(width: 3, height: 3))

        assertPNGSnapshot(matching: pngData, as: .image)
    }


    // MARK: - Private

    private func loadSVGData(for imageName: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: imageName, withExtension: "svg"))
        return try Data(contentsOf: url)
    }

    private func assertPNGSnapshot(
        matching value: @autoclosure () throws -> Data,
        as snapshotting: Snapshotting<NSImage, NSImage>,
        named name: String? = nil,
        record recording: Bool = false,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        assertSnapshot(
            matching: try XCTUnwrap(NSImage(data: value())),
            as: .image,
            named: name,
            record: recording,
            timeout: timeout,
            file: file,
            testName: testName,
            line: line
        )
    }
}
