package main

import fmt "core:fmt"
import "core:math/rand"
import mem "core:mem"
import rl "vendor:raylib"

rand_palette_img: rl.Image


main :: proc() {

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(960, 540, "Unnamed")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)


	ui_ctx: UI_Context = ui_context_make(measure_text)
	defer ui_context_delete(ui_ctx)

	rand_palette_img = rl.LoadImage("assets/images/beleko.png")
	defer rl.UnloadImage(rand_palette_img)

	for !rl.WindowShouldClose() {
		rand.reset(0)

		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		if begin_layout(&ui_ctx, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())) {
			// Root
			if open_layout(
				&ui_ctx,
				{
					id = "root_content",
					width = grow(),
					height = grow(),
					padding = pad_all(16),
					child_gap = 12,
					layout_direction = .Top_To_Bottom,
				},
			) {

				// ============================================================
				// Header: fixed height, horizontal children
				// ============================================================
				if open_layout(
					&ui_ctx,
					{
						id = "header",
						width = grow(),
						height = fixed(64),
						padding = Layout_Padding{left = 12, right = 12, top = 8, bottom = 8},
						child_gap = 16,
						layout_direction = .Left_To_Right,
					},
				) {
					open_text(&ui_ctx, {id = "header_title", content = "Complex Layout Test"})

					open_text(
						&ui_ctx,
						{
							id = "header_description",
							content = "This is a fixed-height horizontal container with multiple text children.",
						},
					)
				}

				// ============================================================
				// Main area: horizontal, two major panels
				// ============================================================
				if open_layout(
					&ui_ctx,
					{
						id = "main",
						width = grow(),
						height = grow(),
						child_gap = 12,
						layout_direction = .Left_To_Right,
					},
				) {

					// --------------------------------------------------------
					// Left panel: fixed width, vertical
					// --------------------------------------------------------
					if open_layout(
						&ui_ctx,
						{
							id = "left_panel",
							width = fixed(220, min = 180, max = 260),
							height = grow(),
							padding = pad_all(12),
							child_gap = 10,
							layout_direction = .Top_To_Bottom,
						},
					) {
						open_text(&ui_ctx, {id = "left_title", content = "Left Panel"})

						if open_layout(
							&ui_ctx,
							{
								id = "left_fixed",
								width = grow(),
								height = fixed(80),
								padding = pad_all(8),
								child_gap = 6,
								layout_direction = .Top_To_Bottom,
							},
						) {
							open_text(
								&ui_ctx,
								{id = "left_fixed_title", content = "Fixed height child"},
							)

							open_text(
								&ui_ctx,
								{
									id = "left_fixed_text",
									content = "This container has a fixed height and a growing width.",
								},
							)
						}

						if open_layout(
							&ui_ctx,
							{
								id = "left_fit",
								width = grow(),
								height = fit(),
								padding = pad_all(8),
								child_gap = 6,
								layout_direction = .Top_To_Bottom,
							},
						) {
							open_text(
								&ui_ctx,
								{
									id = "left_fit_text",
									content = "This container uses fit height. Its size comes from its contents.",
								},
							)
						}

						if open_layout(
							&ui_ctx,
							{
								id = "left_grow",
								width = grow(),
								height = grow(min = 70, max = 180),
								padding = pad_all(8),
								child_gap = 6,
								layout_direction = .Top_To_Bottom,
							},
						) {
							open_text(&ui_ctx, {id = "left_grow_title", content = "Bounded grow"})

							open_text(
								&ui_ctx,
								{
									id = "left_grow_text",
									content = "This region has a minimum and maximum height so the grow distribution has to respect constraints.",
								},
							)
						}
					}

					// --------------------------------------------------------
					// Right panel: growing width, vertical
					// --------------------------------------------------------
					if open_layout(
						&ui_ctx,
						{
							id = "right_panel",
							width = grow(min = 300),
							height = grow(),
							padding = pad_all(12),
							child_gap = 10,
							layout_direction = .Top_To_Bottom,
						},
					) {
						open_text(&ui_ctx, {id = "right_title", content = "Right Panel"})

						// Long text intended to wrap.
						if open_layout(
							&ui_ctx,
							{
								id = "text_wrap_area",
								width = grow(),
								height = fit(),
								padding = pad_all(8),
								child_gap = 6,
								layout_direction = .Top_To_Bottom,
							},
						) {
							open_text(
								&ui_ctx,
								{
									id = "long_text",
									content = "Neque porro quisquam est qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit. This paragraph is intentionally long enough to exercise wrapping when the available width becomes small.",
								},
							)
						}

						// Horizontal sizing test with unequal children.
						if open_layout(
							&ui_ctx,
							{
								id = "row_test",
								width = grow(),
								height = fixed(120),
								padding = pad_all(8),
								child_gap = 8,
								layout_direction = .Left_To_Right,
							},
						) {
							if open_layout(
								&ui_ctx,
								{
									id = "row_a",
									width = fixed(80),
									height = grow(),
									padding = pad_all(6),
									layout_direction = .Top_To_Bottom,
								},
							) {
								open_text(&ui_ctx, {id = "row_a_text", content = "80px"})
							}

							if open_layout(
								&ui_ctx,
								{
									id = "row_b",
									width = grow(min = 100, max = 240),
									height = grow(),
									padding = pad_all(6),
									layout_direction = .Top_To_Bottom,
								},
							) {
								open_text(
									&ui_ctx,
									{id = "row_b_text", content = "Grow with min/max"},
								)
							}

							if open_layout(
								&ui_ctx,
								{
									id = "row_c",
									width = grow(),
									height = grow(),
									padding = pad_all(6),
									layout_direction = .Top_To_Bottom,
								},
							) {
								open_text(
									&ui_ctx,
									{id = "row_c_text", content = "Remaining space"},
								)
							}
						}

						// Nested horizontal/vertical combination.
						if open_layout(
							&ui_ctx,
							{
								id = "nested_test",
								width = grow(),
								height = grow(),
								child_gap = 8,
								layout_direction = .Left_To_Right,
							},
						) {
							if open_layout(
								&ui_ctx,
								{
									id = "nested_left",
									width = grow(min = 120),
									height = grow(),
									padding = pad_all(8),
									child_gap = 4,
									layout_direction = .Top_To_Bottom,
								},
							) {
								open_text(&ui_ctx, {id = "nested_left_1", content = "Nested A"})

								open_text(
									&ui_ctx,
									{
										id = "nested_left_2",
										content = "A second line with enough text to potentially wrap.",
									},
								)
							}


						}
					}
				}

				// ============================================================
				// Footer: fixed height with mixed children
				// ============================================================
				if open_layout(
					&ui_ctx,
					{
						id = "footer",
						width = grow(),
						height = fixed(72),
						padding = pad_all(10),
						child_gap = 12,
						layout_direction = .Left_To_Right,
					},
				) {
					open_text(&ui_ctx, {id = "footer_left", content = "Footer"})

					if open_layout(
						&ui_ctx,
						{
							id = "footer_middle",
							width = grow(min = 120, max = 300),
							height = grow(),
							padding = pad_all(6),
						},
					) {
						open_text(
							&ui_ctx,
							{id = "footer_middle_text", content = "Bounded grow footer section"},
						)
					}

					open_text(&ui_ctx, {id = "footer_right", content = "End"})
				}
			}
		}


		render_commands(ui_ctx.render_commands[:], get_random_color)
	}

}

get_random_color :: proc() -> rl.Color {
	return rl.GetImageColor(rand_palette_img, i32(rand.float32() * f32(rand_palette_img.width)), 0)
}
