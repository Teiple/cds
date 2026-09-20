package game

import "../ui"
import "core:math"
import "core:math/linalg"
import sg "sokol/gfx"

Rect :: ui.Rect

Viewport :: struct {
	base_size:       [2]f32,
	dest_rect:       Rect,
	scale:           f32,
	vmouse_position: [2]f32,
}

viewport_make :: proc(base_size: [2]f32) -> Viewport {
	return {base_size = base_size, vmouse_position = base_size * 0.5}
}

viewport_update :: proc(vp: ^Viewport, window_size: [2]f32) {
	if window_size.x <= 0 || window_size.y <= 0 {
		return
	}

	vp.scale = min(
		window_size.x / vp.base_size.x,
		window_size.y / vp.base_size.y,
	)

	dest_size := vp.base_size * vp.scale

	vp.dest_rect = {
		x      = (window_size.x - dest_size.x) * 0.5,
		y      = (window_size.y - dest_size.y) * 0.5,
		width  = dest_size.x,
		height = dest_size.y,
	}
}

viewport_apply :: proc(vp: Viewport) {
	sg.apply_viewportf(
		vp.dest_rect.x,
		vp.dest_rect.y,
		vp.dest_rect.width,
		vp.dest_rect.height,
		true,
	)
	sg.apply_scissor_rectf(
		vp.dest_rect.x,
		vp.dest_rect.y,
		vp.dest_rect.width,
		vp.dest_rect.height,
		true,
	)
}

viewport_apply_hardware :: viewport_apply

viewport_handle_mouse_delta :: proc(vp: ^Viewport, delta: [2]f32) {
	if vp.scale <= 0 {
		return
	}
	scaled_delta := delta / vp.scale
	vp.vmouse_position += scaled_delta
	vp.vmouse_position.x = clamp(vp.vmouse_position.x, 0, vp.base_size.x)
	vp.vmouse_position.y = clamp(vp.vmouse_position.y, 0, vp.base_size.y)
}

viewport_screen_to_virtual :: proc(
	vp: Viewport,
	screen_pos: [2]f32,
) -> [2]f32 {
	if vp.scale <= 0 {
		return {}
	}
	vpos := (screen_pos - {vp.dest_rect.x, vp.dest_rect.y}) / vp.scale
	vpos.x = clamp(vpos.x, 0, vp.base_size.x)
	vpos.y = clamp(vpos.y, 0, vp.base_size.y)
	return vpos
}

viewport_get_mouse_position :: proc(vp: Viewport) -> [2]f32 {
	return vp.vmouse_position
}
