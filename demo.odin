package main

import "base:runtime"
import "core:fmt"
import "core:hash"
import "core:os"
import "core:time"

ITERATIONS :: 1_000_000

main :: proc() {
	entry_point := #location()
	loc := #location()
	entry_dir := os.dir(entry_point.file_path)

	// 1. Full Path + Adler32
	{
		start := time.tick_now()
		h: u32 = 0
		for _ in 0 ..< ITERATIONS {
			h = hash_full_adler(loc)
		}
		duration := time.duration_milliseconds(time.tick_since(start))
		fmt.printfln(
			"Full path (Adler32):     %.2f ms (%.2f ns/op, hash: %v)",
			duration,
			(duration * 1_000_000.0) / ITERATIONS,
			h,
		)
	}

	// 2. Sliced Path + Adler32
	{
		start := time.tick_now()
		h: u32 = 0
		for _ in 0 ..< ITERATIONS {
			h = hash_slice_adler(entry_dir, loc)
		}
		duration := time.duration_milliseconds(time.tick_since(start))
		fmt.printfln(
			"Sliced path (Adler32):   %.2f ms (%.2f ns/op, hash: %v)",
			duration,
			(duration * 1_000_000.0) / ITERATIONS,
			h,
		)
	}

	// 3. Sliced Path + FNV32a
	{
		start := time.tick_now()
		h: u32 = 0
		for _ in 0 ..< ITERATIONS {
			h = hash_slice_fnv(entry_dir, loc)
		}
		duration := time.duration_milliseconds(time.tick_since(start))
		fmt.printfln(
			"Sliced path (FNV32a):    %.2f ms (%.2f ns/op, hash: %v)",
			duration,
			(duration * 1_000_000.0) / ITERATIONS,
			h,
		)
	}

	// 4. Procedure Name + FNV32a
	{
		start := time.tick_now()
		h: u32 = 0
		for _ in 0 ..< ITERATIONS {
			h = hash_procedure_fnv(loc)
		}
		duration := time.duration_milliseconds(time.tick_since(start))
		fmt.printfln(
			"Procedure name (FNV32a): %.2f ms (%.2f ns/op, hash: %v)",
			duration,
			(duration * 1_000_000.0) / ITERATIONS,
			h,
		)
	}

	{
		start := time.tick_now()
		h: u64 = 0
		for _ in 0 ..< ITERATIONS {
			h = hash_slice_fnv64(entry_dir, loc)
		}
		duration := time.duration_milliseconds(time.tick_since(start))
		fmt.printfln(
			"Sliced path (FNV64a):    %.2f ms (%.2f ns/op, hash: %v)",
			duration,
			(duration * 1_000_000.0) / ITERATIONS,
			h,
		)
	}

	{
		start := time.tick_now()
		h: u64 = 0
		for _ in 0 ..< ITERATIONS {
			h = hash_procedure_fnv64(loc)
		}
		duration := time.duration_milliseconds(time.tick_since(start))
		fmt.printfln(
			"Procedure name (FNV64a): %.2f ms (%.2f ns/op, hash: %v)",
			duration,
			(duration * 1_000_000.0) / ITERATIONS,
			h,
		)
	}
}

hash_full_adler :: proc(loc: runtime.Source_Code_Location) -> u32 {
	line := transmute([4]u8)loc.line
	column := transmute([4]u8)loc.column
	h := hash.adler32(transmute([]u8)loc.file_path)
	h = hash.adler32(line[:], h)
	h = hash.adler32(column[:], h)
	return h
}

hash_slice_adler :: proc(
	entry_dir: string,
	loc: runtime.Source_Code_Location,
) -> u32 {
	line := transmute([4]u8)loc.line
	column := transmute([4]u8)loc.column
	h := hash.adler32(transmute([]u8)(loc.file_path[len(entry_dir):]))
	h = hash.adler32(line[:], h)
	h = hash.adler32(column[:], h)
	return h
}

hash_slice_fnv :: proc(
	entry_dir: string,
	loc: runtime.Source_Code_Location,
) -> u32 {
	line := transmute([4]u8)loc.line
	column := transmute([4]u8)loc.column
	h := hash.fnv32a(transmute([]u8)(loc.file_path[len(entry_dir):]))
	h = hash.fnv32a(line[:], h)
	h = hash.fnv32a(column[:], h)
	return h
}

hash_procedure_fnv :: proc(loc: runtime.Source_Code_Location) -> u32 {
	line := transmute([4]u8)loc.line
	column := transmute([4]u8)loc.column
	h := hash.fnv32a(transmute([]u8)loc.procedure)
	h = hash.fnv32a(line[:], h)
	h = hash.fnv32a(column[:], h)
	return h
}

hash_slice_fnv64 :: proc(
	entry_dir: string,
	loc: runtime.Source_Code_Location,
) -> u64 {
	line := transmute([4]u8)loc.line
	column := transmute([4]u8)loc.column
	h := hash.fnv64a(transmute([]u8)(loc.file_path[len(entry_dir):]))
	h = hash.fnv64a(line[:], h)
	h = hash.fnv64a(column[:], h)
	return h
}

hash_procedure_fnv64 :: proc(loc: runtime.Source_Code_Location) -> u64 {
	line := transmute([4]u8)loc.line
	column := transmute([4]u8)loc.column
	h := hash.fnv64a(transmute([]u8)loc.procedure)
	h = hash.fnv64a(line[:], h)
	h = hash.fnv64a(column[:], h)
	return h
}
