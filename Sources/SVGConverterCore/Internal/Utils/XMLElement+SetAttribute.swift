//
//  XMLElement+SetAttribute.swift
//  svg2png
//
//  Created by Alexandre Podlewski on 31/03/2022.
//

import Foundation

extension XMLElement {
    func set(value: String, for attributeName: String) {
        if let existingAttribute = attribute(forName: attributeName) {
            existingAttribute.stringValue = value
        } else {
            let node = XMLNode(kind: .attribute)
            node.name = attributeName
            node.stringValue = value
            addAttribute(node)
        }
    }
}
