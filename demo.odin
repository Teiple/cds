package demo

import "core:fmt"
import "core:math"

main :: proc() {
	a: f32 = 1.0
	b: f32 = a + (math.F32_EPSILON - 1e-7)

	fmt.println(a == b)
	fmt.println(a)
	fmt.println(b)
}
