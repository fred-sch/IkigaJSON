import Foundation

public struct JSONArray {
    let buffer: Buffer
    var slice: UnsafeRawBufferPointer {
        return UnsafeRawBufferPointer(start: buffer.pointer, count: reader.byteCount)
    }
    var description: JSONDescription
    var reader: ReadOnlyJSONDescription { return description.readOnly }
    
    public init(data: Data) throws {
        self.buffer = Buffer(copying: data)
        
        let size = data.count
        
        let description = try data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
            return try JSONParser.scanValue(fromPointer: pointer, count: size)
        }
        self.description = description
        
        guard reader.type == .array else {
            throw JSONError.expectedObject
        }
    }
    
    public var count: Int {
        return reader.arrayObjectCount()
    }
    
    internal init(buffer: Buffer, description: JSONDescription) {
        self.buffer = buffer
        self.description = description
    }
    
    public mutating func remove(at index: Int) {
        _checkBounds(index)
        
        let indexStart = reader.offset(forIndex: index)
        let bounds = reader.dataBounds(at: indexStart)
        description.removeArrayDescription(at: indexStart, jsonOffset: bounds.offset, removedJSONLength: bounds.length)
    }
    
    private func _checkBounds(_ index: Int) {
        if index >= reader.arrayObjectCount() {
            fatalError("Index out of bounds. \(index) > \(count)")
        } else if index < 0 {
            fatalError("Negative index requested for JSONArray.")
        }
    }
    
    public subscript(index: Int) -> JSONValue {
        get {
            _checkBounds(index)
            
            let pointer = buffer.pointer.bindMemory(to: UInt8.self, capacity: buffer.size)
            // Array descriptions are 17 bytes
            var offset = 17
            
            for _ in 0..<index {
                reader.skip(withOffset: &offset)
            }
            
            let type = reader.type(atOffset: offset)!

            switch type {
            case .object, .array:
                let indexLength = reader.indexLength(atOffset: offset)
                let jsonBounds = reader.dataBounds(at: offset)
                
                var subDescription = description.slice(from: offset, length: indexLength)
                subDescription.advanceAllJSONOffsets(by: -jsonBounds.offset)
                let subBuffer = buffer.slice(bounds: jsonBounds)
                
                if type == .object {
                    return JSONObject(buffer: subBuffer, description: subDescription)
                } else {
                    return JSONArray(buffer: subBuffer, description: subDescription)
                }
            case .boolTrue:
                return true
            case .boolFalse:
                return false
            case .string:
                return reader.dataBounds(at: offset).makeString(from: pointer, escaping: false, unicode: true)!
            case .stringWithEscaping:
                return reader.dataBounds(at: offset).makeString(from: pointer, escaping: true, unicode: true)!
            case .integer:
                return reader.dataBounds(at: offset).makeInt(from: pointer)!
            case .floatingNumber:
                return reader.dataBounds(at: offset).makeDouble(from: pointer, floating: true)!
            case .null:
                return NSNull()
            }
        }
        set {
            _checkBounds(index)
            
            let offset = reader.offset(forIndex: index)
            description.rewrite(buffer: buffer, to: newValue, at: offset)
        }
    }
}

extension String {
    public func escapingAppend(to bytes: inout [UInt8]) -> Bool {
        var escaped = false
        
        var characters = [UInt8](self.utf8)
        
        var i = characters.count
        nextByte: while i > 0 {
            i = i &- 1
            
            switch characters[i] {
            case .newLine:
                escaped = true
                characters[i] = .backslash
                characters.insert(.n, at: i &+ 1)
            case .carriageReturn:
                escaped = true
                characters[i] = .backslash
                characters.insert(.r, at: i &+ 1)
            case .quote:
                escaped = true
                characters.insert(.backslash, at: i)
            case .tab:
                escaped = true
                characters[i] = .backslash
                characters.insert(.t, at: i &+ 1)
            case .backslash:
                escaped = true
                characters.insert(.backslash, at: i &+ 1)
            default:
                continue
            }
        }
        
        bytes.append(contentsOf: characters)
        
        return escaped
    }
}
