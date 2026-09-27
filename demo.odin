package main

import "base:intrinsics"
import "core:fmt"

Sparse_Enum :: enum {
	A = 0,
	B = 1,
	G = 5,
}

Draw_Proc_Wrapper :: struct($T: typeid) where intrinsics.type_is_proc(T) {
	draw: T,
}

g_state := struct {
	last_id:          u64,
	dropdown_options: any,
}{}

type_hint :: proc(hint: $E) {
	dropdown :: proc(
		options: ^($T/[$E]string),
		id: Maybe(u64) = nil,
	) -> (
		draw_dropdown: Draw_Proc_Wrapper(proc()),
	) where intrinsics.type_is_enum(E) {
		g_state.last_id = id.? or_else 0
		g_state.dropdown_options = options
		return {draw = proc() {
				options := g_state.dropdown_options.(^T)
				for label in options^ {
					fmt.println(label)
				}
			}}
	}
}

main :: proc() {

	dropdown(&#sparse[Sparse_Enum]string{.A = "A", .B = "B", .G = "G"}).draw()
}
