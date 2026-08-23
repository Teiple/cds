package demo

import "core:fmt"

main :: proc() {
	ilu := "我爱你"
	for ch, i in ilu {
		fmt.println(ch, i)
	}
}
