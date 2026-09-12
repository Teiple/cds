package viewport
import rl "vendor:raylib"

Viewport :: struct {
	base_size:        rl.Vector2,
	destination_rect: rl.Rectangle,
	scale:            rl.Vector2,
	render_texture:   rl.RenderTexture,
}

init :: proc(base_size: rl.Vector2) -> Viewport {
	rt := rl.LoadRenderTexture(i32(base_size.x), i32(base_size.y))
	rl.SetTextureFilter(rt.texture, .BILINEAR)
	return {base_size = base_size, render_texture = rt}
}

update :: proc(vp: ^Viewport, window_size: rl.Vector2) {
	rt_src: rl.Rectangle = {0, 0, vp.base_size.x, -vp.base_size.y}
	// keep aspect
	vp.scale = min(window_size.x / vp.base_size.x, window_size.y / vp.base_size.y)

	dest_size := vp.base_size * vp.scale

	vp.destination_rect = {
		(window_size.x - dest_size.x) * 0.5,
		(window_size.y - dest_size.y) * 0.5,
		dest_size.x,
		dest_size.y,
	}
}

begin :: proc(vp: ^Viewport) {
	rl.BeginTextureMode(vp.render_texture)
	rl.ClearBackground(rl.RAYWHITE)
}

end :: proc(vp: ^Viewport) {
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


close_viewport :: proc(ctx: ^Viewport) {
	rl.UnloadRenderTexture(ctx.render_texture)
}

window_to_viewport_position :: proc(vp: Viewport, postion: rl.Vector2) -> rl.Vector2 {
	dest_rect_pos: rl.Vector2 = {vp.destination_rect.x, vp.destination_rect.y}
	return (postion - dest_rect_pos) / vp.scale
}

window_to_viewport_vector :: proc(vp: Viewport, vec: rl.Vector2) -> rl.Vector2 {
	return vec / vp.scale
}
