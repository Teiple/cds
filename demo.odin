package main

import "core:fmt"

Struct_1 :: struct {
	data_1 : f32,
}

Struct_2 :: struct {
	data_2 : f32,
}

Union :: union {
	Struct_1,
	Struct_2,
}

Global :: struct {
	u : Union,
} 

g : Global = {
	u = Struct_1 {
		data_1 = 12,
	}
}

get_u :: proc() -> ^Union {
	return &g.u
}

main :: proc() {
	u := &get_u().(Struct_1)
	fmt.println(u.data_1)
}
