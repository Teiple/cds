package main

import "core:fmt"
Union :: union {
	f32,
	i32,
}

main :: proc() {
	fmt.println("Hello World")
	u: Union = i32(2)
	uf := u.(f32)
	fmt.printfln("Value %v", uf)
}
