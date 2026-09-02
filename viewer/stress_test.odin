package main

import fmt "core:fmt"
import ui "ui"

// Static, deliberately oversized descendants make the nested clip intersections
// visible at every level. No element-level conditional or loop rendering is used.
draw_layout_stress_test :: proc() {
	// Outer clip: establishes the first clipping region.
	if ui.layout(
		id = "stress-root",
		width = ui.grow(),
		height = ui.grow(),
		padding = ui.pad_all(18),
		child_gap = 14,
		layout_direction = .Top_To_Bottom,
		background_color = get_random_color(),
		corner_radius = 18,
		border = ui.border(3, get_random_color(-0.2, true)),
		shadow = ui.shadow(radius = 14, offset = {5, 7}),
		clip = true,
	) {
		ui.text(
			id = "stress-title",
			content = "Nested clip + border + shadow stress test",
			font_size = 24,
			color = get_random_color(-0.45),
		)

		// Two side-by-side branches exercise independent nested clip stacks.
		if ui.layout(
			id = "stress-columns",
			width = ui.grow(),
			height = ui.grow(),
			padding = ui.pad_all(10),
			child_gap = 14,
			layout_direction = .Left_To_Right,
			child_alignment = {x = .Left, y = .Top},
		) {
			// LEFT BRANCH ----------------------------------------------------
			if ui.layout(
				id = "stress-left",
				width = ui.percent(0.5),
				height = ui.grow(),
				padding = ui.pad_all(14),
				child_gap = 10,
				layout_direction = .Top_To_Bottom,
				background_color = get_random_color(),
				corner_radius = 14,
				border = ui.border(2, get_random_color(-0.25, true)),
				shadow = ui.shadow(radius = 12, offset = {4, 5}),
				clip = true,
			) {
				ui.text(
					id = "stress-left-label",
					content = "LEFT / 3 clip levels",
					font_size = 18,
					color = get_random_color(-0.5),
				)

				// Intentionally wider than its parent: outer clip must trim it.
				if ui.layout(
					id = "stress-left-level-1",
					width = ui.fixed(520),
					height = ui.fixed(210),
					padding = ui.pad_all(12),
					child_gap = 12,
					layout_direction = .Left_To_Right,
					background_color = get_random_color(),
					corner_radius = 12,
					border = ui.border(4, get_random_color(-0.15, true)),
					shadow = ui.shadow(radius = 10, offset = {8, 8}),
					clip = true,
				) {
					// Another oversized child: tests intersection of clip #1 + #2.
					if ui.layout(
						id = "stress-left-level-2",
						width = ui.fixed(390),
						height = ui.fixed(170),
						padding = ui.pad_all(12),
						child_gap = 10,
						layout_direction = .Top_To_Bottom,
						background_color = get_random_color(),
						corner_radius = 10,
						border = ui.border(3, get_random_color(-0.15, true)),
						shadow = ui.shadow(radius = 9, offset = {7, -4}),
						clip = true,
					) {
						ui.text(
							id = "stress-left-level-2-label",
							content = "deep child",
							font_size = 20,
							color = get_random_color(-0.45),
						)

						// Deliberately overflows the level-2 clip on both axes.
						if ui.layout(
							id = "stress-left-overflow",
							width = ui.fixed(330),
							height = ui.fixed(250),
							padding = ui.pad_all(10),
							background_color = get_random_color(),
							corner_radius = 8,
							border = ui.border(5, get_random_color(-0.1, true)),
							shadow = ui.shadow(radius = 15, offset = {-10, 10}),
							clip = true,
						) {
							ui.text(
								id = "stress-left-overflow-a",
								content = "This content intentionally extends past multiple clip boundaries.",
								font_size = 16,
								color = get_random_color(-0.55),
							)

							if ui.layout(
								id = "stress-left-nested-box",
								width = ui.fixed(440),
								height = ui.fixed(90),
								padding = ui.pad_all(8),
								background_color = get_random_color(),
								corner_radius = 16,
								border = ui.border(2, get_random_color(-0.2, true)),
								shadow = ui.shadow(radius = 7, offset = {12, 0}),
								// clip = true,
							) {
								ui.text(
									id = "stress-left-nested-box-text",
									content = "Horizontal overflow + nested clip.",
									font_size = 18,
									color = get_random_color(-0.5),
								)
							}
						}
					}
				}
			}

			// RIGHT BRANCH ---------------------------------------------------
			if ui.layout(
				id = "stress-right",
				width = ui.percent(0.5),
				height = ui.grow(),
				padding = ui.pad_all(14),
				child_gap = 10,
				layout_direction = .Top_To_Bottom,
				background_color = get_random_color(),
				corner_radius = 14,
				border = ui.border(2, get_random_color(-0.25, true)),
				shadow = ui.shadow(radius = 12, offset = {-4, 5}),
				clip = true,
			) {

				ui.text(
					id = "stress-right-label",
					content = "RIGHT / offset shadow cases",
					font_size = 18,
					color = get_random_color(-0.5),
				)

				// Wide child with a negative shadow offset.
				if ui.layout(
					id = "stress-right-top",
					width = ui.fixed(460),
					height = ui.fixed(125),
					padding = ui.pad_all(10),
					child_gap = 8,
					layout_direction = .Left_To_Right,
					background_color = get_random_color(),
					corner_radius = 20,
					border = ui.border(6, get_random_color(-0.1, true)),
					shadow = ui.shadow(radius = 18, offset = {-12, -9}),
					clip = true,
				) {
					ui.text(
						id = "stress-right-top-text",
						content = "Large border + large shadow + clip",
						font_size = 19,
						color = get_random_color(-0.5),
					)

					if ui.layout(
						id = "stress-right-chip",
						width = ui.fixed(250),
						height = ui.fixed(90),
						padding = ui.pad_all(8),
						background_color = get_random_color(),
						corner_radius = 24,
						border = ui.border(3, get_random_color(-0.2, true)),
						shadow = ui.shadow(radius = 6, offset = {16, 6}),
						clip = true,
					) {
						ui.text(
							id = "stress-right-chip-text",
							content = "nested chip",
							font_size = 17,
							color = get_random_color(-0.45),
						)
					}
				}

				// Deep stack with alternating clipping directions/sizes.
				if ui.layout(
					id = "stress-right-stack-1",
					width = ui.percent(1.0),
					height = ui.grow(),
					padding = ui.pad_all(12),
					child_gap = 9,
					layout_direction = .Top_To_Bottom,
					background_color = get_random_color(),
					corner_radius = 12,
					border = ui.border(4, get_random_color(-0.15, true)),
					shadow = ui.shadow(radius = 11, offset = {5, -7}),
					clip = true,
				) {
					if ui.layout(
						id = "stress-right-stack-2",
						width = ui.fixed(430),
						height = ui.fixed(290),
						padding = ui.pad_all(12),
						child_gap = 9,
						layout_direction = .Left_To_Right,
						background_color = get_random_color(),
						corner_radius = 10,
						border = ui.border(2, get_random_color(-0.25, true)),
						shadow = ui.shadow(radius = 13, offset = {-8, 8}),
						clip = true,
					) {
						if ui.layout(
							id = "stress-right-stack-3",
							width = ui.fixed(240),
							height = ui.fixed(340),
							padding = ui.pad_all(10),
							child_gap = 7,
							layout_direction = .Top_To_Bottom,
							background_color = get_random_color(),
							corner_radius = 8,
							border = ui.border(5, get_random_color(-0.1, true)),
							shadow = ui.shadow(radius = 9, offset = {9, 11}),
							clip = true,
						) {
							ui.text(
								id = "stress-right-stack-3-a",
								content = "Vertical overflow",
								font_size = 18,
								color = get_random_color(-0.5),
							)

							if ui.layout(
								id = "stress-right-stack-4",
								width = ui.fixed(310),
								height = ui.fixed(170),
								padding = ui.pad_all(8),
								background_color = get_random_color(),
								corner_radius = 6,
								border = ui.border(3, get_random_color(-0.2, true)),
								shadow = ui.shadow(radius = 5, offset = {-14, 4}),
								clip = true,
							) {
								ui.text(
									id = "stress-right-stack-4-a",
									content = "Intersection clipping should keep only the visible overlap.",
									font_size = 16,
									color = get_random_color(-0.55),
								)
								ui.text(
									id = "stress-right-stack-4-b",
									content = "Borders and shadows should remain visually coherent near clipped edges.",
									font_size = 15,
									color = get_random_color(-0.55),
								)
							}
						}

						if ui.layout(
							id = "stress-right-sibling",
							width = ui.fixed(260),
							height = ui.grow(),
							padding = ui.pad_all(10),
							background_color = get_random_color(),
							corner_radius = 18,
							border = ui.border(4, get_random_color(-0.15, true)),
							shadow = ui.shadow(radius = 16, offset = {10, -10}),
							clip = true,
						) {
							ui.text(
								id = "stress-right-sibling-text",
								content = fmt.tprintf("Sibling after nested clip"),
								font_size = 17,
								color = get_random_color(-0.5),
							)
						}
					}
				}
			}
		}
	}
}
