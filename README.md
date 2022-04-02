# SVGConverter

A library and executable to convert SVG to PNG image using webkit.

## CLI Installation

```bash
swift build -c release
sudo cp -f .build/release/SVGConverter /usr/local/bin/svgConverter
```

<details>
    <summary>Uninstallation</summary>

    sudo rm /usr/local/bin/svgConverter
</details>

## Usage

From CLI:
```bash
svgConverter file.svg output.png 1920 1080
# Or if you have not installed the executable:
# swift swift run SVGConverter file.svg output.png 1920 1080
```

<details>
    <summary>svgConverter help</summary>

```
USAGE: svg-converter <input-path> <output-path> <width> <height> [--no-svg-fix] [--quiet]

ARGUMENTS:
  <input-path>            Path to the svg file you want to convert
  <output-path>           Destination path for the created png
  <width>                 Width of the output image
  <height>                Height of the output image

OPTIONS:
  --no-svg-fix            Set this to true if you do not want this tool to automatically add a viewBox attribute if it is possible. Without viewBox the svg cannot be resized, but it can still be converted at its natural size
  --quiet                 Setting this to true prevent any output in standard error output
  -h, --help              Show help information.
```

</details>

From code:
```swift
import SVGConverterCore

func run() async throws {
    let svgData = try Data(contentsOf: "file.svg")
    let renderer = await SVGRenderer()
    let pngData = try await renderer.render(svgData: svgData, size: CGSize(width: 1920, height: 1080))
    try pngData.write(to: URL(fileURLWithPath: "output.png"))
}
```
