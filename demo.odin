package main

import "core:fmt"

@(deferred_none = end_func)
func :: proc() -> bool {
	fmt.println("Start func")
	return true
}

end_func :: proc() {
	fmt.println("End func")
}

Func_Struct :: struct {
	func_field: type_of(func),
}

main :: proc() {
	func_struct: Func_Struct = {
		func_field = func,
	}
	if func_struct.func_field() {
		fmt.println("Body")
	}
}
