package main

import "core:fmt"

add_u32 :: asm(a: u32, b: u32) -> (res: u32) [a -> res] {
	add res, b
}

main :: proc() {
	fmt.println(add_u32(12, 12))
}
