package demo

import "core:fmt"

main :: proc() {
	// for i := 0; some_proc(); i += 1 {
	// 	if i >= 10 do break
	// }

	some_proc()
	some_proc()
	some_proc()
	some_proc()
}


@(deferred_none = end_some_proc)
some_proc :: proc() -> bool {
	fmt.println("some")
	return true
}

end_some_proc :: proc() {
	fmt.println("end")
}
