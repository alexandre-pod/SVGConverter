//
//  SVGRenderingWarnings.swift
//
//
//  Created by Alexandre Podlewski on 02/04/2022.
//

import Foundation

public struct SVGRenderingWarnings: Error {

    public let localizedDescription: String

    internal init(_ message: String) {
        self.localizedDescription = message
    }
}
