package main

import "core:fmt"

@(require_results, deferred_none = end_layout)
layout :: proc() -> bool {
	fmt.println("open layout")
	return true
}

begin_layout := layout

end_layout :: proc() {
	fmt.println("end layout")
}

main :: proc() {
	if begin_layout() {
	}
	fmt.println("end!")
}
