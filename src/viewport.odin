package game
import rl "vendor:raylib"

Viewport :: struct {
	base_size:        rl.Vector2,
	camera:           ^rl.Camera,
	destination_rect: rl.Rectangle,
	scale:            rl.Vector2,
	render_texture:   rl.RenderTexture,
	vmouse_position:  rl.Vector2,
}

viewport_make :: proc(base_size: rl.Vector2, camera: ^rl.Camera) -> Viewport {
	rt := rl.LoadRenderTexture(i32(base_size.x), i32(base_size.y))
	rl.SetTextureFilter(rt.texture, .BILINEAR)

	// use virtual position to have confined cursor
	rl.DisableCursor()

	return {
		base_size = base_size,
		render_texture = rt,
		camera = camera,
		vmouse_position = base_size * 0.5,
	}
}

viewport_update :: proc(vp: ^Viewport, window_size: rl.Vector2) {
	rt_src: rl.Rectangle = {0, 0, vp.base_size.x, -vp.base_size.y}
	// keep aspect
	vp.scale = min(
		window_size.x / vp.base_size.x,
		window_size.y / vp.base_size.y,
	)

	dest_size := vp.base_size * vp.scale

	vp.destination_rect = {
		(window_size.x - dest_size.x) * 0.5,
		(window_size.y - dest_size.y) * 0.5,
		dest_size.x,
		dest_size.y,
	}

	if rl.IsWindowFocused() {
		delta := rl.GetMouseDelta() / vp.scale
		vp.vmouse_position += delta
		vp.vmouse_position.x = clamp(vp.vmouse_position.x, 0, vp.base_size.x)
		vp.vmouse_position.y = clamp(vp.vmouse_position.y, 0, vp.base_size.y)
	}
}

viewport_begin :: proc(vp: ^Viewport) {
	rl.BeginTextureMode(vp.render_texture)
	rl.ClearBackground(rl.RAYWHITE)
}

viewport_end :: proc(vp: ^Viewport) {
	rl.EndTextureMode()

	rl.BeginDrawing()

	rl.ClearBackground(rl.BLACK)

	rl.DrawTexturePro(
		vp.render_texture.texture,
		{0, 0, vp.base_size.x, -vp.base_size.y},
		vp.destination_rect,
		{0, 0},
		0,
		rl.WHITE,
	)

	rl.EndDrawing()
}

viewport_close :: proc(ctx: ^Viewport) {
	rl.EnableCursor()
	rl.UnloadRenderTexture(ctx.render_texture)
}


viewport_get_mouse_position :: proc(vp: Viewport) -> rl.Vector2 {
	return vp.vmouse_position
}

viewport_get_mouse_delta :: proc(vp: Viewport) -> rl.Vector2 {
	return rl.GetMouseDelta() / vp.scale
}

viewport_get_mouse_world_position_on_zplane :: proc(
	vp: Viewport,
	z_plane: f32 = 0,
) -> (
	world_pos: rl.Vector3,
	hit: bool,
) #optional_ok {
	get_mouse_to_world_ray :: proc(vp: Viewport) -> rl.Ray {
		vp_mouse_position := viewport_get_mouse_position(vp)
		return rl.GetScreenToWorldRayEx(
			vp_mouse_position,
			vp.camera^,
			i32(vp.base_size.x),
			i32(vp.base_size.y),
		)
	}

	ray := get_mouse_to_world_ray(vp)

	if abs(ray.direction.z) < 0.00001 do return {}, false

	t := (z_plane - ray.position.z) / ray.direction.z
	if t < 0 do return {}, false

	hit_pos := ray.position + ray.direction * t
	hit_pos.z = z_plane

	return hit_pos, true
}
