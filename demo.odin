package main

import "core:fmt"
some_data := [?]i32{1, 2, 3, 4}

main :: proc() {
	fmt.println(rawptr(&some_data))
	free(&some_data)
}
