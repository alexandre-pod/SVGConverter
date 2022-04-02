//
//  Result+throwingMap.swift
//  svg2png
//
//  Created by Alexandre Podlewski on 30/03/2022.
//

import Foundation

extension Result where Failure: Error {
    func throwingMap<MapSuccess>(_ closure: (Success) throws -> MapSuccess) -> Result<MapSuccess, Error> {
        switch self {
        case .success(let success):
            do {
                return try .success(closure(success))
            } catch {
                return .failure(error)
            }
        case .failure(let failure):
            return .failure(failure)
        }
    }
}
