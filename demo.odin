package main

import "core:fmt"
Union :: union {
	f32,
	string,
}

main :: proc() {
	u: Union = "hello world"

	res, ok := u.(f32)
	fmt.println(res, ok)
}
