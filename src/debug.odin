package game

import "core:fmt"
import mem "core:mem"

@(private)
g_track: mem.Tracking_Allocator

debug_track_allocator_init :: proc() {
	mem.tracking_allocator_init(&g_track, context.allocator)
	context.allocator = mem.tracking_allocator(&g_track)
	g_odin_ctx = context
}

debug_track_allocator_stop :: proc() {
	if len(g_track.allocation_map) > 0 {
		fmt.eprintf(
			"=== %v allocations not freed: ===\n",
			len(g_track.allocation_map),
		)
		for _, entry in g_track.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	}
	if len(g_track.bad_free_array) > 0 {
		fmt.eprintf(
			"=== %v incorrect frees: ===\n",
			len(g_track.bad_free_array),
		)
		for entry in g_track.bad_free_array {
			fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
		}
	}
	mem.tracking_allocator_destroy(&g_track)
}
