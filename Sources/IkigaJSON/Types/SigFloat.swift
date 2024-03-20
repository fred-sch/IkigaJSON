public struct SigFloat: CustomStringConvertible, Encodable, ExpressibleByFloatLiteral {
    public typealias FloatLiteralType = Float

    public let value: Float
    public let decimalPlaces: UInt8

    public init(_ value: Float, decimalPlaces: UInt8 = 2) {
        self.value = value
        self.decimalPlaces = decimalPlaces
    }

    public init(floatLiteral value: Float) {
        self.value = value
        self.decimalPlaces = 2    
    }

    @inline(__always) var isFinite: Bool {
        self.value.isFinite
    }

    public var description: String {
        String(format: "%.\(decimalPlaces)f", value)
    }
}
