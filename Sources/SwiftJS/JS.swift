import Foundation
import Duktape
import Files

public typealias JsFunction = (JS) -> Int32;

public class JS {
    static public var CODES = [OpaquePointer : String]();
    static public var FUNCTIONS = [Int32 : JsFunction]();
    static private let LOCK = NSLock();

    public let ctx : OpaquePointer
    private let shouldDeinit : Bool;
    private var varIndex : Int32 = -1;
    private var functionList = [Int32]();

    public init() {
        self.ctx = duk_create_heap_default();
        self.shouldDeinit = true;
    }

    public init(ctx : OpaquePointer) {
        self.ctx = ctx;
        self.shouldDeinit = false;
    }

    deinit {
        if (self.shouldDeinit) {
            duk_destroy_heap(self.ctx);

            // Убиваем функции
            JS.LOCK.lock();
            for magicIndex in self.functionList {
                JS.FUNCTIONS.removeValue(forKey: magicIndex);
            }
            JS.LOCK.unlock();
        }
    }

    public func addVariable(name : String? = nil, value : [String: Value?]) -> Bool {
        let obj_idx = duk_push_object(self.ctx);
        for (key, val) in value {
            if (addVariable(value: val)) {
                duk_put_prop_string(ctx, obj_idx, key);
            }
        }

        if let name = name {
            duk_put_global_string(self.ctx, name);
        }

        return true;
    }

    public func addVariable(name : String? = nil, value : Value?) -> Bool {
        if (value == nil) {
            duk_push_null(self.ctx);
        } else {
            switch (value!) {
                case is String: duk_push_string(self.ctx, value as! String);
                case is Double: duk_push_number(self.ctx, value as! Double);
                case is Float: duk_push_number(self.ctx, Double(value as! Float));
                case is Bool: duk_push_boolean(self.ctx, ((value as! Bool) == true) ? 1 : 0);

                case is Int32: duk_push_int(self.ctx, value as! Int32);
                case is Int16: duk_push_int(self.ctx, Int32(value as! Int16));
                case is Int8: duk_push_int(self.ctx, Int32(value as! Int8));
                case is UInt32: duk_push_uint(self.ctx, value as! UInt32);
                case is UInt16: duk_push_uint(self.ctx, UInt32(value as! UInt16));
                case is UInt8: duk_push_uint(self.ctx, UInt32(value as! UInt8));

                case is UInt:
                    let v = value as! UInt;
                    if (v <= UInt32.max) {
                        duk_push_uint(self.ctx, UInt32(v))
                    } else {
                        duk_push_number(self.ctx, Double(v))
                    }

                case is Int:
                    let v = value as! Int;
                    if (v >= Int32.min) && (v <= Int32.max) {
                        duk_push_int(self.ctx, Int32(v))
                    } else {
                        duk_push_number(self.ctx, Double(v))
                    }

                case is Array<Value?>:
                    let arr = value as! Array<Value?>;
                    let arr_idx = duk_push_array(self.ctx);
                    for (key, val) in arr.enumerated() {
                        if (addVariable(value: val)) {
                            duk_put_prop_index(self.ctx, arr_idx, UInt32(key));
                        }
                    }

                case is ODictionary<String, Value>:
                    let obj = value as! ODictionary<String, Value>;
                    let obj_idx = duk_push_object(self.ctx);
                    for (key, val) in obj {
                        if (addVariable(value: val)) {
                            duk_put_prop_string(ctx, obj_idx, key);
                        }
                    }

                default:
                    return false;
            }
        }

        if let name = name {
            duk_put_global_string(self.ctx, name);
        }

        return true;
    }

    public func pop() {
        duk_pop(self.ctx);
    }

    public func getArgc() -> Int32 {
        return duk_get_top(self.ctx);
    }

    private func getIndex(_ index : Int32? = nil) -> Int32 {
        if let index = index {
            return index;
        }

        self.varIndex += 1;
        return self.varIndex;
    }

    public func getValue(_ index : Int32? = nil) -> Value? {
        let idx = getIndex(index);

        if (duk_is_string(self.ctx, idx)  == 1) { return getString(idx);  }
        if (duk_is_boolean(self.ctx, idx) == 1) { return getBool(idx); }
        if (duk_is_array(self.ctx, idx)   == 1) { return getArray(idx); }
        if (duk_is_object(self.ctx, idx)   == 1) { return getObjectLinked(idx); }
        if (duk_is_number(self.ctx, idx)  == 1) {
            if let t = String(validatingUTF8:duk_to_string(self.ctx, idx)) {
                if (t.contains(".")) {
                    return Double(t);
                } else {
                    return Int(t);
                }
            } else {
                return getDouble(idx);
            }
        }

        return nil;
    }

    public func getString(_ index : Int32? = nil) -> String? {
        return getText(buf: duk_get_string(self.ctx, getIndex(index)));
    }

    public func getDouble(_ index : Int32? = nil) -> Double? {
        return duk_get_number(self.ctx, getIndex(index))
    }

    public func getFloat(_ index : Int32? = nil) -> Float? {
        if let res = getDouble(getIndex(index)) {
            return Float(res);
        }

        return nil;
    }

    public func getBool(_ index : Int32? = nil) -> Bool? {
        let idx = getIndex(index);
        if (isUndefined(idx)) {
            return nil;
        }

        return (duk_require_boolean(self.ctx, idx) != 0);
    }

    public func getInt32(_ index : Int32? = nil) -> Int32? {
        return duk_get_int(self.ctx, getIndex(index));
    }

    public func getUInt32(_ index : Int32? = nil) -> UInt32? {
        return duk_get_uint(self.ctx, getIndex(index));
    }

    public func getInt(_ index : Int32? = nil) -> Int? {
        if let res = getInt32(getIndex(index)) {
            return Int(res);
        }

        return nil;
    }

    public func getUInt(_ index : Int32? = nil) -> UInt? {
        if let res = getUInt32(getIndex(index)) {
            return UInt(res);
        }

        return nil;
    }

    public func getArray(_ index : Int32? = nil) -> Array<Value?> {
        let idx = getIndex(index);
        let n = duk_get_length(self.ctx, idx);

        var arr = [Value?]();
        for i in 0..<n {
            duk_get_prop_index(ctx, idx, UInt32(i));
            arr.append(getValue(-1));
            duk_pop(ctx);
        }

        return arr;
    }

    public func getObjectLinked(_ index : Int32? = nil) -> ODictionary<String, Value> {
        let idx = getIndex(index);
        var result = ODictionary<String, Value>();

        duk_enum(self.ctx, idx, 0);

        while (duk_next(self.ctx, -1, 1) != 0) {
            if let key = getString(-2), let val = getValue(-1) {
                result[key] = val;
            }

            duk_pop_2(self.ctx);
        }

        duk_pop(self.ctx);

        return result;
    }

    public func getObject(_ index : Int32? = nil) -> [String : Value?] {
        let idx = getIndex(index);
        var result = [String : Value?]();

        duk_enum(self.ctx, idx, 0);

        while (duk_next(self.ctx, -1, 1) != 0) {
            if let key = getString(-2) {
                result[key] = getValue(-1);
            }

            duk_pop_2(self.ctx);
        }

        duk_pop(self.ctx);

        return result;
    }

    public func isUndefined(_ index : Int32? = nil) -> Bool {
        let idx = getIndex(index);
        return duk_is_undefined(self.ctx, idx) != 0;
    }

    public func createFunction(name : String? = nil, valueCount : Int = 0, _ closure : @escaping JsFunction) -> Bool {
        defer {
            JS.LOCK.unlock();
        }

        JS.LOCK.lock();
        if (JS.FUNCTIONS.count == 255) {
            print("Reached limit of functions");
            return false;
        }

        var magicIndex : Int32 = -129;
        for i:Int32 in -128...127 {
            if (JS.FUNCTIONS[i] == nil) {
                magicIndex = i;
                break;
            }
        }

        if (magicIndex == -129) {
            print("Reached limit of functions");
            return false;
        }

        self.functionList.append(magicIndex);
        JS.FUNCTIONS[magicIndex] = closure;

        wrapperFunction(self.ctx, valueCount : Int32(valueCount), magicIndex : magicIndex);

        if let name = name {
            duk_put_global_string(self.ctx, name);
        }

        return true;
    }

    public func overrideModSearch(_ closure : @escaping JsFunction) {
        duk_get_global_string(self.ctx, "Duktape");

        let _ = createFunction(valueCount: 4, closure);
        duk_put_prop_string(self.ctx, -2, "modSearch");
    }

    public func initModSearch(path : String) {
        overrideModSearch() { js in
            if let id = js.getString() {
                guard let file = try? File(path: "\(path)/\(id)") else {
                    return -1;
                }

                if let str = try? file.readAsString() {
                    let _ = js.addVariable(value: str);
                    return 1;
                }
            }

            return -1;
        };
    }

    public func execute(code : String, safe : Bool = true) -> (is_err : Bool, result : String) {
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

        if (ret == DUK_EXEC_ERROR) {
            duk_get_prop_string(self.ctx, -1, "stack");
        }

        let result = String(validatingUTF8:duk_safe_to_string(ctx, -1)!)!
        duk_pop(self.ctx);

        print(result)

        return (is_err : (ret != DUK_EXEC_SUCCESS), result : result);
    }

    private func getText(buf : UnsafePointer<Int8>?) -> String? {
        if let buf = buf, let utf8String = String.init(validatingUTF8 : buf) {
            return utf8String;
        }

        return nil;
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
