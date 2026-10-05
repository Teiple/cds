package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import mem "core:mem"
import shaders "shaders"
import sg "sokol/gfx"

@(private)
g_track: mem.Tracking_Allocator

Debug_Vertex :: struct {
	pos:   [3]f32,
	color: [4]u8,
	uv:    [2]u16,
}

Debug_Drawer :: struct {
	lines_pipeline: sg.Pipeline,
	vertex_buffer:  sg.Buffer,
	capacity:       int,
	lines:          [dynamic]Debug_Vertex,
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

debug_drawer_init :: proc(d: ^Debug_Drawer, capacity: int = 16384) {
	d.capacity = capacity
	d.lines = make([dynamic]Debug_Vertex, 0, capacity)

	pip_desc: sg.Pipeline_Desc = {
		shader = sg.make_shader(shaders.unlit_shader_desc(sg.query_backend())),
		primitive_type = .LINES,
		depth = {
			compare       = .LESS_EQUAL,
			write_enabled = false,
		},
		cull_mode = .NONE,
		layout = {
			attrs = {
				shaders.ATTR_unlit_pos = {buffer_index = 0, format = .FLOAT3},
				shaders.ATTR_unlit_color0 = {
					buffer_index = 0,
					format = .UBYTE4N,
				},
				shaders.ATTR_unlit_texcoord0 = {
					buffer_index = 0,
					format = .SHORT2N,
				},
			},
		},
	}
	d.lines_pipeline = sg.make_pipeline(pip_desc)

	d.vertex_buffer = sg.make_buffer({
		usage = {vertex_buffer = true, dynamic_update = true},
		size = uint(capacity * size_of(Debug_Vertex)),
	})
}

debug_drawer_destroy :: proc(d: ^Debug_Drawer) {
	sg.destroy_pipeline(d.lines_pipeline)
	sg.destroy_buffer(d.vertex_buffer)
	delete(d.lines)
}

debug_draw_line :: proc(p0, p1: [3]f32, color: [4]u8 = {255, 255, 255, 255}) {
	d := &g_state.debug_drawer
	append(&d.lines, Debug_Vertex{pos = p0, color = color, uv = {0, 0}})
	append(&d.lines, Debug_Vertex{pos = p1, color = color, uv = {0, 0}})
}

debug_draw_ray :: proc(origin, dir: [3]f32, length: f32 = 1.0, color: [4]u8 = {255, 255, 255, 255}) {
	debug_draw_line(origin, origin + linalg.normalize(dir) * length, color)
}

debug_draw_box :: proc(
	center: [3]f32,
	size: [3]f32,
	rot: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
	color: [4]u8 = {255, 255, 255, 255},
) {
	half := size * 0.5
	corners := [8][3]f32 {
		{-half.x, -half.y, -half.z},
		{ half.x, -half.y, -half.z},
		{ half.x,  half.y, -half.z},
		{-half.x,  half.y, -half.z},
		{-half.x, -half.y,  half.z},
		{ half.x, -half.y,  half.z},
		{ half.x,  half.y,  half.z},
		{-half.x,  half.y,  half.z},
	}

	rot_mat := linalg.matrix3_from_quaternion_f32(rot)
	for &c in corners {
		c = center + rot_mat * c
	}

	edges := [12][2]int {
		{0, 1}, {1, 2}, {2, 3}, {3, 0},
		{4, 5}, {5, 6}, {6, 7}, {7, 4},
		{0, 4}, {1, 5}, {2, 6}, {3, 7},
	}

	for e in edges {
		debug_draw_line(corners[e[0]], corners[e[1]], color)
	}
}

debug_draw_sphere :: proc(
	center: [3]f32,
	radius: f32,
	segments: int = 24,
	color: [4]u8 = {255, 255, 255, 255},
) {
	step := (2.0 * math.PI) / f32(segments)

	for i in 0 ..< segments {
		a0 := f32(i) * step
		a1 := f32(i + 1) * step

		c0, s0 := math.cos(a0) * radius, math.sin(a0) * radius
		c1, s1 := math.cos(a1) * radius, math.sin(a1) * radius

		debug_draw_line(center + {c0, 0, s0}, center + {c1, 0, s1}, color)
		debug_draw_line(center + {c0, s0, 0}, center + {c1, s1, 0}, color)
		debug_draw_line(center + {0, c0, s0}, center + {0, c1, s1}, color)
	}
}

debug_draw_grid :: proc(slices: int = 10, spacing: f32 = 1.0, color: [4]u8 = {100, 100, 100, 255}) {
	half_extent := f32(slices) * spacing * 0.5
	for i in 0 ..= slices {
		pos := -half_extent + f32(i) * spacing
		debug_draw_line({pos, 0, -half_extent}, {pos, 0, half_extent}, color)
		debug_draw_line({-half_extent, 0, pos}, {half_extent, 0, pos}, color)
	}
}

debug_render :: proc(d: ^Debug_Drawer, camera: ^Camera) {
	if len(d.lines) == 0 do return

	if len(d.lines) > d.capacity {
		sg.destroy_buffer(d.vertex_buffer)
		d.capacity = max(d.capacity * 2, len(d.lines))
		d.vertex_buffer = sg.make_buffer({
			usage = {vertex_buffer = true, dynamic_update = true},
			size = uint(d.capacity * size_of(Debug_Vertex)),
		})
	}

	sg.update_buffer(
		d.vertex_buffer,
		{
			ptr = raw_data(d.lines),
			size = size_of(Debug_Vertex) * len(d.lines),
		},
	)

	sg.apply_pipeline(d.lines_pipeline)

	vs_params: shaders.Vs_Params = {
		mvp = camera_view_projection_matrix(camera),
	}
	sg.apply_uniforms(
		shaders.UB_vs_params,
		{ptr = &vs_params, size = size_of(vs_params)},
	)

	bindings := g_state.renderer.bindings
	bindings.vertex_buffers[0] = d.vertex_buffer
	bindings.index_buffer = {}
	sg.apply_bindings(bindings)

	sg.draw(0, i32(len(d.lines)), 1)
	clear(&d.lines)
}
