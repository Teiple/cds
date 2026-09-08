package viewport
import rl "vendor:raylib"

Viewport_Context :: struct {
	base_size:        rl.Vector2,
	destination_rect: rl.Rectangle,
	render_texture:   rl.RenderTexture,
}

init_viewport :: proc(base_size: rl.Vector2) -> Viewport_Context {
	rt := rl.LoadRenderTexture(i32(base_size.x), i32(base_size.y))
	return {base_size = base_size, render_texture = rt}
}

update :: proc(ctx: ^Viewport_Context, window_size: rl.Vector2) {
	rt_src: rl.Rectangle = {0, 0, ctx.base_size.x, -ctx.base_size.y}
	// keep aspect
	scale := min(window_size.x / ctx.base_size.x, window_size.y / ctx.base_size.y)

	dest_size := ctx.base_size * scale

	ctx.destination_rect = {
		(window_size.x - dest_size.x) * 0.5,
		(window_size.y - dest_size.y) * 0.5,
		dest_size.x,
		dest_size.y,
	}
}

begin :: proc(ctx: ^Viewport_Context) {
	rl.BeginTextureMode(ctx.render_texture)
	rl.ClearBackground(rl.RAYWHITE)
}

end :: proc(ctx: ^Viewport_Context) {
	rl.EndTextureMode()

	rl.BeginDrawing()

	rl.ClearBackground(rl.BLACK)

	rl.DrawTexturePro(
		ctx.render_texture.texture,
		{0, 0, ctx.base_size.x, -ctx.base_size.y},
		ctx.destination_rect,
		{0, 0},
		0,
		rl.WHITE,
	)

	rl.EndDrawing()
}


close_viewport :: proc(ctx: ^Viewport_Context) {
	rl.UnloadRenderTexture(ctx.render_texture)
}
