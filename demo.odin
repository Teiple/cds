package main

import "core:fmt"
import "core:hash"
import "core:strings"
import "core:time"

ITERATIONS :: 200_000

TEST_LENGTHS := [?]int{8, 16, 32, 64, 128, 256, 512}

main :: proc() {
	sample_buffer := strings.repeat(
		"abcdefghijklmnopqrstuvwxyz0123456789_/",
		20,
	)
	defer delete(sample_buffer)

	for len in TEST_LENGTHS {
		chunk := transmute([]u8)sample_buffer[:len]

		{
			start := time.tick_now()
			h: u32 = 0
			for _ in 0 ..< ITERATIONS {
				h = hash.adler32(chunk)
			}
			ms := time.duration_milliseconds(time.tick_since(start))
			ns_per_op := (ms * 1_000_000.0) / ITERATIONS
			ns_per_byte := ns_per_op / f64(len)
			fmt.printfln(
				"Len %3d | Adler32: %6.2f ns/op (%4.2f ns/char)",
				len,
				ns_per_op,
				ns_per_byte,
			)
		}

		{
			start := time.tick_now()
			h: u64 = 0
			for _ in 0 ..< ITERATIONS {
				h = hash.fnv64a(chunk)
			}
			ms := time.duration_milliseconds(time.tick_since(start))
			ns_per_op := (ms * 1_000_000.0) / ITERATIONS
			ns_per_byte := ns_per_op / f64(len)
			fmt.printfln(
				"Len %3d | FNV64a:  %6.2f ns/op (%4.2f ns/char)",
				len,
				ns_per_op,
				ns_per_byte,
			)
		}
	}
}
