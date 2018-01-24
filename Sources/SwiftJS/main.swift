import Foundation
import Duktape

func myJsFunc(js: JS) -> Int32 {
    let a = js.getArray(0)

    let _ = js.addVariable(value: a)
    return 1;
}


let js = JS();
let _ = js.addVariable(name: "d", value: ["foo1", 123, true]);
let _ = js.createFunction(name: "testFunc", valueCount: 1, myJsFunc);
let _ = js.execute(code: "testFunc(['foo1', 123, true]);");