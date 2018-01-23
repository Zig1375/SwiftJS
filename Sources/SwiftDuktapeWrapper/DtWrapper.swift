import Foundation
import Duktape

public class DtWrapper {
    public let ctx : OpaquePointer

    init() {
        self.ctx = duk_create_heap_default();
    }

    deinit {
        duk_destroy_heap(self.ctx);
    }

    func addGlobalVariable(name : String, value : String, is_global : Bool = true) {
        duk_push_string(self.ctx, value);

        if (is_global) {
            duk_put_global_string(self.ctx, name);
        }
    }

    func addGlobalVariable(name : String, value : Double, is_global : Bool = true) {
        duk_push_number(self.ctx, value);

        if (is_global) {
            duk_put_global_string(self.ctx, name);
        }
    }

    func addGlobalVariable(name : String, value : Int32, is_global : Bool = true) {
        duk_push_int(self.ctx, value);

        if (is_global) {
            duk_put_global_string(self.ctx, name);
        }
    }

    func addGlobalVariable(name : String, value : UInt32, is_global : Bool = true) {
        duk_push_uint(self.ctx, value);

        if (is_global) {
            duk_put_global_string(self.ctx, name);
        }
    }

    func addGlobalVariable(name : String, value : UInt) {
        if (value <= UInt32.max) {
            addGlobalVariable(name: name, value : UInt32(value));
        } else {
            addGlobalVariable(name: name, value : Double(value));
        }
    }

    func addGlobalVariable(name : String, value : Int) {
        if ((value >= Int32.min) && (value <= Int32.max)) {
            addGlobalVariable(name: name, value : Int32(value));
        } else {
            addGlobalVariable(name: name, value : Double(value));
        }
    }

    func addGlobalVariable(name : String, value : UInt64) {
        addGlobalVariable(name: name, value: UInt(value));
    }

    func addGlobalVariable(name : String, value : Int64) {
        addGlobalVariable(name: name, value: Int(value));
    }

    func addGlobalVariable(name : String, value : Int16) {
        addGlobalVariable(name: name, value: Int32(value));
    }

    func addGlobalVariable(name : String, value : UInt16) {
        addGlobalVariable(name: name, value: UInt32(value));
    }

    func addGlobalVariable(name : String, value : UInt8) {
        addGlobalVariable(name: name, value: UInt32(value));
    }

    func addGlobalVariable(name : String, value : Int8) {
        addGlobalVariable(name: name, value: Int32(value));
    }

    func addGlobalVariable(name : String, value : Bool, is_global : Bool = true) {
        duk_push_boolean(self.ctx, value ? 1 : 0);

        if (is_global) {
            duk_put_global_string(self.ctx, name);
        }
    }

    func addGlobalVariable(name : String, value : Array<String>) {
        let arr_idx = duk_push_array(self.ctx);

        for (key, val) in value.enumerated() {
            addGlobalVariable(name: "array", value: val, is_global: false);
            duk_put_prop_index(self.ctx, arr_idx, UInt32(key));
        }

        duk_put_global_string(self.ctx, name);
    }








    func execute(code : String, safe : Bool = true) -> String {
        let ret : Int32 = DUK_EXEC_SUCCESS;
        if (safe) {/*
            withUnsafeMutablePointer(to: self.ctx) { ptr in
                let optr = OpaquePointer(ptr)!;
                ret = duk_safe_call(optr, { ctx in
                    duk_eval_string(ctx, code)
                    return 1
                }, 0, 1);
            }
            */
            duk_eval_string(self.ctx, code);
        } else {
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
}


/*
func dummy_upper_case(ctx : OpaquePointer?) -> Int32 {
    return 1;
}

//duk_push_c_function(ctx, dummy_upper_case, 1);
//duk_put_global_string(ctx, "MyObject");


*/