//
//  SVGRenderingError.swift
//
//
//  Created by Alexandre Podlewski on 02/04/2022.
//

import Foundation

public enum SVGRenderingError: Error {
    case renderingAlreadyInProgress
    case invalidSVGData
    case cgImageConversionFailed
    case alphaChannelRemovalFailed
    case pngImageConversionFailed
    case invalidState
}

public extension SVGRenderingError {

    // MARK: - Error

    var localizedDescription: String {
        switch self {
        case .renderingAlreadyInProgress:
            return "A rendering is already in progress. An SVGRenderer only supports the rendering of one SVG at a time."
        case .invalidSVGData:
            return "The SVG data is malformed"
        case .cgImageConversionFailed:
            return "Internal error, conversion to cgImage failed"
        case .alphaChannelRemovalFailed:
            return "Internal error, failed to remove alpha channel from the generated image"
        case .pngImageConversionFailed:
            return "Internal error, getting png representation from cgImage failed"
        case .invalidState:
            return "Unexpected error"
        }
    }
}
