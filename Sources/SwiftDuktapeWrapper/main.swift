import Foundation


let js = DtWrapper();
js.addGlobalVariable(name: "d", value: ["foo1", "bar2"]);

let _ = js.execute(code: "print( JSON.stringify(d) );");

