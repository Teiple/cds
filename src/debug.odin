package game

import "core:fmt"
import mem "core:mem"
import sg "sokol/gfx"

@(private)
g_track: mem.Tracking_Allocator

Debug_Drawer :: struct {
	lines_pipeline:     sg.Pipeline,
	triangles_pipeline: sg.Pipeline,
	line_buffer:        sg.Buffer,
	triangle_buffer:    sg.Buffer,
	line_vertices:      [dynamic]Vertex,
	triangle_vertices:  [dynamic]Vertex,
}

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

debug_render :: proc(d: ^Debug_Drawer) {
	if len(d.triangle_vertices) > 0 {
		sg.update_buffer(
			d.triangle_buffer,
			{
				ptr = raw_data(d.triangle_vertices),
				size = size_of(Vertex) * len(d.triangle_vertices),
			},
		)
		sg.apply_pipeline(d.triangles_pipeline)
		sg.draw(0, i32(len(d.triangle_vertices)), 1)
		clear(&d.triangle_vertices)
	}

	if len(d.line_vertices) > 0 {
		sg.update_buffer(
			d.line_buffer,
			{
				ptr = raw_data(d.line_vertices),
				size = size_of(Vertex) * len(d.line_vertices),
			},
		)
		sg.apply_pipeline(d.lines_pipeline)
		sg.draw(0, i32(len(d.line_vertices)), 1)
		clear(&d.line_vertices)
	}
}
