package main

import "core:fmt"
some_string_array: [8]string

main :: proc() {
	some_string_array = "hello world"
	fmt.println(some_string_array)
}
