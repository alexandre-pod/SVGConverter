//
//  CGImage+Utils.swift
//
//
//  Created by Alexandre Podlewski on 07/04/2022.
//

import CoreGraphics

extension CGImage {
    func removingAlphaChannel() -> CGImage? {
        let cgBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

        let cgContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: cgBitmapInfo.rawValue
        )
        cgContext?.draw(self, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))

        return cgContext?.makeImage()
    }
}
