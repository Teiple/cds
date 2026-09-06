package main

import "core:fmt"
Stateful_Content_Wrapper :: struct($T: typeid) {
	content: proc(data: T),
}

Stateless_Content :: proc()

Stateful_Content :: type_of(Stateful_Content_Wrapper(i32){}.content)

gen_proc :: proc(
	data: $T,
	content: $U,
) where (T == 0 && U == Stateless_Content) ||
	(U == type_of(Stateful_Content_Wrapper(T){}.content)) {

}


main :: proc() {
	gen_proc(0, proc() {

	})
}
