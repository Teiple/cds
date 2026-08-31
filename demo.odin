package main

import rl "vendor:raylib"


Rounded_Rectangle :: struct {
	corner_radius:        rl.Vector4,
	shadow_radius:        f32,
	shadow_offset:        rl.Vector2,
	shadow_scale:         f32,
	border_thickness:     f32,
	rectangle_loc:        i32,
	radius_loc:           i32,
	color_loc:            i32,
	shadow_radius_loc:    i32,
	shadow_offset_loc:    i32,
	shadow_scale_loc:     i32,
	shadow_color_loc:     i32,
	border_thickness_loc: i32,
	border_color_loc:     i32,
}


main :: proc() {
	screen_width: i32 = 800
	screen_height: i32 = 450

	rl.InitWindow(screen_width, screen_height, "raylib [shaders] example - rounded rectangle")
	defer rl.CloseWindow()

	// Load shader
	shader := rl.LoadShader("./shaders/base.vs", "./shaders/rounded_rect.fs")
	defer rl.UnloadShader(shader)

	// Create rounded rectangle
	rounded_rectangle := create_rounded_rectangle({5.0, 10.0, 15.0, 20.0}, 20.0, {0.0, -5.0}, 0.95, 5.0, shader)

	rectangle_color :: rl.BLUE
	shadow_color :: rl.DARKBLUE
	border_color :: rl.SKYBLUE

	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		// ------------------------------------------------------------
		// Rounded rectangle
		// ------------------------------------------------------------

		rec := rl.Rectangle {
			x      = 50,
			y      = 70,
			width  = 110,
			height = 60,
		}

		rl.DrawRectangleLines(i32(rec.x) - 20, i32(rec.y) - 20, i32(rec.width) + 40, i32(rec.height) + 40, rl.DARKGRAY)

		rl.DrawText("Rounded rectangle", i32(rec.x) - 20, i32(rec.y) - 35, 10, rl.DARKGRAY)

		// Flip Y axis to match shader coordinate system
		rec.y = f32(screen_height) - rec.y - rec.height

		rectangle_data := [4]f32{rec.x, rec.y, rec.width, rec.height}

		rectangle_color_data := [4]f32 {
			f32(rectangle_color.r) / 255.0,
			f32(rectangle_color.g) / 255.0,
			f32(rectangle_color.b) / 255.0,
			f32(rectangle_color.a) / 255.0,
		}

		transparent := [4]f32{0, 0, 0, 0}

		rl.SetShaderValue(shader, rounded_rectangle.rectangle_loc, &rectangle_data, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.color_loc, &rectangle_color_data, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.shadow_color_loc, &transparent, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.border_color_loc, &transparent, .VEC4)

		rl.BeginShaderMode(shader)
		rl.DrawRectangle(0, 0, screen_width, screen_height, rl.WHITE)
		rl.EndShaderMode()


		// ------------------------------------------------------------
		// Shadow
		// ------------------------------------------------------------

		rec = rl.Rectangle {
			x      = 50,
			y      = 200,
			width  = 110,
			height = 60,
		}

		rl.DrawRectangleLines(i32(rec.x) - 20, i32(rec.y) - 20, i32(rec.width) + 40, i32(rec.height) + 40, rl.DARKGRAY)

		rl.DrawText("Rounded rectangle shadow", i32(rec.x) - 20, i32(rec.y) - 35, 10, rl.DARKGRAY)

		rec.y = f32(screen_height) - rec.y - rec.height

		rectangle_data = [4]f32{rec.x, rec.y, rec.width, rec.height}

		shadow_color_data := [4]f32 {
			f32(shadow_color.r) / 255.0,
			f32(shadow_color.g) / 255.0,
			f32(shadow_color.b) / 255.0,
			f32(shadow_color.a) / 255.0,
		}

		rl.SetShaderValue(shader, rounded_rectangle.rectangle_loc, &rectangle_data, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.color_loc, &transparent, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.shadow_color_loc, &shadow_color_data, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.border_color_loc, &transparent, .VEC4)

		rl.BeginShaderMode(shader)
		rl.DrawRectangle(0, 0, screen_width, screen_height, rl.WHITE)
		rl.EndShaderMode()


		// ------------------------------------------------------------
		// Border
		// ------------------------------------------------------------

		rec = rl.Rectangle {
			x      = 50,
			y      = 330,
			width  = 110,
			height = 60,
		}

		rl.DrawRectangleLines(i32(rec.x) - 20, i32(rec.y) - 20, i32(rec.width) + 40, i32(rec.height) + 40, rl.DARKGRAY)

		rl.DrawText("Rounded rectangle border", i32(rec.x) - 20, i32(rec.y) - 35, 10, rl.DARKGRAY)

		rec.y = f32(screen_height) - rec.y - rec.height

		rectangle_data = [4]f32{rec.x, rec.y, rec.width, rec.height}

		border_color_data := [4]f32 {
			f32(border_color.r) / 255.0,
			f32(border_color.g) / 255.0,
			f32(border_color.b) / 255.0,
			f32(border_color.a) / 255.0,
		}

		rl.SetShaderValue(shader, rounded_rectangle.rectangle_loc, &rectangle_data, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.color_loc, &transparent, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.shadow_color_loc, &transparent, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.border_color_loc, &border_color_data, .VEC4)

		rl.BeginShaderMode(shader)
		rl.DrawRectangle(0, 0, screen_width, screen_height, rl.WHITE)
		rl.EndShaderMode()


		// ------------------------------------------------------------
		// All three combined
		// ------------------------------------------------------------

		rec = rl.Rectangle {
			x      = 240,
			y      = 80,
			width  = 500,
			height = 300,
		}

		rl.DrawRectangleLines(i32(rec.x) - 30, i32(rec.y) - 30, i32(rec.width) + 60, i32(rec.height) + 60, rl.DARKGRAY)

		rl.DrawText("Rectangle with all three combined", i32(rec.x) - 30, i32(rec.y) - 45, 10, rl.DARKGRAY)

		rec.y = f32(screen_height) - rec.y - rec.height

		rectangle_data = [4]f32{rec.x, rec.y, rec.width, rec.height}

		rl.SetShaderValue(shader, rounded_rectangle.rectangle_loc, &rectangle_data, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.color_loc, &rectangle_color_data, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.shadow_color_loc, &shadow_color_data, .VEC4)

		rl.SetShaderValue(shader, rounded_rectangle.border_color_loc, &border_color_data, .VEC4)

		rl.BeginShaderMode(shader)
		rl.DrawRectangle(0, 0, screen_width, screen_height, rl.WHITE)
		rl.EndShaderMode()


		rl.DrawText(
			"(c) Rounded rectangle SDF by Iñigo Quilez. MIT License.",
			screen_width - 300,
			screen_height - 20,
			10,
			rl.BLACK,
		)

		rl.EndDrawing()
	}
}


create_rounded_rectangle :: proc(
	corner_radius: rl.Vector4,
	shadow_radius: f32,
	shadow_offset: rl.Vector2,
	shadow_scale: f32,
	border_thickness: f32,
	shader: rl.Shader,
) -> Rounded_Rectangle {
	rec := Rounded_Rectangle {
		corner_radius        = corner_radius,
		shadow_radius        = shadow_radius,
		shadow_offset        = shadow_offset,
		shadow_scale         = shadow_scale,
		border_thickness     = border_thickness,
		rectangle_loc        = rl.GetShaderLocation(shader, "rectangle"),
		radius_loc           = rl.GetShaderLocation(shader, "radius"),
		color_loc            = rl.GetShaderLocation(shader, "color"),
		shadow_radius_loc    = rl.GetShaderLocation(shader, "shadowRadius"),
		shadow_offset_loc    = rl.GetShaderLocation(shader, "shadowOffset"),
		shadow_scale_loc     = rl.GetShaderLocation(shader, "shadowScale"),
		shadow_color_loc     = rl.GetShaderLocation(shader, "shadowColor"),
		border_thickness_loc = rl.GetShaderLocation(shader, "borderThickness"),
		border_color_loc     = rl.GetShaderLocation(shader, "borderColor"),
	}

	update_rounded_rectangle(&rec, shader)

	return rec
}


update_rounded_rectangle :: proc(rec: ^Rounded_Rectangle, shader: rl.Shader) {
	rl.SetShaderValue(shader, rec.radius_loc, &rec.corner_radius, .VEC4)

	rl.SetShaderValue(shader, rec.shadow_radius_loc, &rec.shadow_radius, .FLOAT)

	rl.SetShaderValue(shader, rec.shadow_offset_loc, &rec.shadow_offset, .VEC2)

	rl.SetShaderValue(shader, rec.shadow_scale_loc, &rec.shadow_scale, .FLOAT)

	rl.SetShaderValue(shader, rec.border_thickness_loc, &rec.border_thickness, .FLOAT)
}
