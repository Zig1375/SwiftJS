import Foundation

public protocol Value {

}

extension String : Value {};
extension Bool   : Value {};

extension Double  : Value {};
extension Float   : Value {};

extension UInt   : Value {};
extension UInt64 : Value {};
extension UInt32 : Value {};
extension UInt16 : Value {};
extension UInt8  : Value {};

extension Int   : Value {};
extension Int64 : Value {};
extension Int32 : Value {};
extension Int16 : Value {};
extension Int8  : Value {};

extension Array : Value {};

