import Foundation
import Duktape

public typealias JsFunction = (JS) -> Int32;

public class JS {
    static public var CODES = [OpaquePointer : String]();
    static public var FUNCTIONS = [Int32 : JsFunction]();

    public let ctx : OpaquePointer
    private let shouldDeinit : Bool;

    init() {
        self.ctx = duk_create_heap_default();
        self.shouldDeinit = true;
    }

    init(ctx : OpaquePointer) {
        self.ctx = ctx;
        self.shouldDeinit = false;
    }

    deinit {
        if (self.shouldDeinit) {
            duk_destroy_heap(self.ctx);
        }
    }

    func addVariable(name : String? = nil, value : Value) -> Bool {
        switch (value) {
            case is String : duk_push_string(self.ctx, value as! String);
            case is Double : duk_push_number(self.ctx, value as! Double);
            case is Float  : duk_push_number(self.ctx, Double(value as! Float));
            case is Bool   : duk_push_boolean(self.ctx, ((value as! Bool) == true) ? 1 : 0);

            case is Int32  : duk_push_int(self.ctx, value as! Int32);
            case is Int16  : duk_push_int(self.ctx, Int32(value as! Int16));
            case is Int8   : duk_push_int(self.ctx, Int32(value as! Int8));
            case is UInt32 : duk_push_uint(self.ctx, value as! UInt32);
            case is UInt16 : duk_push_uint(self.ctx, UInt32(value as! UInt16));
            case is UInt8  : duk_push_uint(self.ctx, UInt32(value as! UInt8));

            case is UInt   :
                let v = value as! UInt;
                if (v <= UInt32.max) {
                    duk_push_uint(self.ctx, UInt32(v))
                } else {
                    duk_push_number(self.ctx, Double(v))
                }

            case is Int   :
                let v = value as! Int;
                if (v >= Int32.min) && (v <= Int32.max) {
                    duk_push_int(self.ctx, Int32(v))
                } else {
                    duk_push_number(self.ctx, Double(v))
                }

            case is Array<Value>:
                let arr = value as! Array<Value>;
                let arr_idx = duk_push_array(self.ctx);
                for (key, val) in arr.enumerated() {
                    if (addVariable(value: val)) {
                        duk_put_prop_index(self.ctx, arr_idx, UInt32(key));
                    }
                }

            default :
                return false;
        }

        if let name = name {
            duk_put_global_string(self.ctx, name);
        }

        return true;
    }

    func pop() {
        duk_pop(self.ctx);
    }

    func getArgc() -> Int32 {
        return duk_get_top(self.ctx);
    }

    func getString(_ index : Int32) -> String {
        return getText(buf: duk_get_string(self.ctx, index));
    }

    func getDouble(_ index : Int32) -> Double {
        return duk_get_number(self.ctx, index)
    }

    func getFloat(_ index : Int32) -> Float {
        return Float(duk_get_number(self.ctx, index));
    }

    func getBool(_ index : Int32) -> Bool {
        return (duk_require_boolean(self.ctx, index) != 0)
    }

    func getInt32(_ index : Int32) -> Int32 {
        return duk_get_int(self.ctx, index);
    }

    func getUInt32(_ index : Int32) -> UInt32 {
        return duk_get_uint(self.ctx, index);
    }

    func getInt(_ index : Int32) -> Int {
        return Int(duk_get_int(self.ctx, index));
    }

    func getUInt(_ index : Int32) -> UInt {
        return UInt(duk_get_uint(self.ctx, index));
    }

    func getArray(_ index : Int32) -> Array<Value> {
        let elIdx = getArgc();
        let n = duk_get_length(self.ctx, index);

        var arr = [Value]();
        for i in 0..<n {
            duk_get_prop_index(ctx, index, UInt32(i));

            if (duk_is_string(self.ctx, elIdx)  == 1) { arr.append(getString(elIdx)); } else
            if (duk_is_number(self.ctx, elIdx)  == 1) { arr.append(getDouble(elIdx)); } else
            if (duk_is_boolean(self.ctx, elIdx) == 1) { arr.append(getBool(elIdx)); }   else
            if (duk_is_array(self.ctx, elIdx)   == 1) { arr.append(getArray(elIdx)); }

            duk_pop(ctx);
        }

        return arr;
    }



    func createFunction(name : String? = nil, valueCount : Int = 0, _ closure : @escaping JsFunction) -> Bool {
        if (JS.FUNCTIONS.count == 255) {
            print("Reached limit of functions");
            return false;
        }

        let magicIndex : Int32 = Int32(JS.FUNCTIONS.count + 1) - 129;
        JS.FUNCTIONS[magicIndex] = closure;

        wrapperFunction(self.ctx, valueCount : Int32(valueCount), magicIndex : magicIndex);

        if let name = name {
            duk_put_global_string(self.ctx, name);
        }

        return true;
    }

    func execute(code : String, safe : Bool = true) -> String {
        let ret : Int32;
        if (safe) {
            JS.CODES[self.ctx] = code;
            ret = duk_safe_call(self.ctx, { (_ ctx: OpaquePointer?) -> duk_ret_t in
                if let ctx = ctx {
                    duk_eval_string(ctx, JS.CODES[ctx]);
                }

                return 1;
            }, 0, 1);

            JS.CODES.removeValue(forKey: ctx);
        } else {
            ret = DUK_EXEC_SUCCESS;
            duk_eval_string(self.ctx, code);
        }

        let result = String(validatingUTF8:duk_safe_to_string(ctx, -1)!)!
        if ret == DUK_EXEC_SUCCESS {
            print("Success: \(result)")
        } else {
            print("Error: \(result)")
        }

        duk_pop(self.ctx);
        return result;
    }

    private func getText(buf : UnsafePointer<Int8>) -> String {
        if let utf8String = String.init(validatingUTF8 : buf) {
            return utf8String;
        }

        return "";
    }
}

/// Turn a `JsFunction` into a `duk_c_function`
private func wrapperFunction(_ ctx: OpaquePointer!, valueCount : Int32, magicIndex : Int32) {
    duk_push_c_lightfunc(ctx, { (_ ctx: OpaquePointer?) -> duk_ret_t in
        if let ctx = ctx {
            let magic = duk_get_current_magic(ctx);
            if let closure = JS.FUNCTIONS[magic] {
                return closure(JS(ctx: ctx));
            }
        }

        return -1;
    }, valueCount, 0, magicIndex);
}
