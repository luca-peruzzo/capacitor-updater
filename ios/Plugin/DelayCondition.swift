//
//  DelayCondition.swift
//  Plugin
//
//  Created by Luca Peruzzo on 12/09/22.
//  Copyright © 2022 Capgo. All rights reserved.
//

import Foundation

private func delayUntilNextValue(value: String) -> DelayUntilNext {
    switch(value) {
        case "background": return .background
        case "kill": return .kill
        case "nativeVersion": return .nativeVersion
        case "date": return .date
        default:
            return .background
    }
}

@objc public class DelayCondition: NSObject, Decodable, Encodable {
    private let kind: DelayUntilNext;
    private let value: String?;
    
    convenience init(kind: String, value: String?) {
        self.init(kind: delayUntilNextValue(value: kind), value: value)
    }
    
    init(kind: DelayUntilNext, value: String?) {
        self.kind = kind
        self.value = value
    }
    
    public required init(from decoder:Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(DelayUntilNext.self, forKey: .kind)
        value = try values.decode(String.self, forKey: .value)
    }
    
    enum CodingKeys: String, CodingKey {
        case kind, value
    }
    
    public func getKind() -> String{
        return self.kind.description
    }
    
    public func getValue() -> String?{
        return self.value
    }
    
    public func toJSON() -> [String: String] {
        return [
            "kind": self.getKind(),
            "value": self.getValue() ?? "",
        ]
    }
    
    public static func == (lhs: DelayCondition, rhs: DelayCondition) -> Bool {
        return lhs.getKind() == rhs.getKind() && lhs.getValue() == rhs.getValue()
    }
    
    public func toString() -> String {
        return "{ \"kind\": \"\(self.getKind())\", \"value\": \"\(self.getValue() ?? "")\"}"
    }
    
}
