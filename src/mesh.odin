package game

import "core:math"
import sg "sokol/gfx"

MESH_DEFAULT_VERTEX_COLOR :: [4]u8{0, 255, 0, 255} // green

Mesh :: struct {
	vertex_buffer:     sg.Buffer,
	index_buffer:      sg.Buffer,
	wire_index_buffer: sg.Buffer,
	index_count:       i32,
	wire_index_count:  i32,
}

mesh_make_from_data :: proc(vertices: []Vertex, indices: []u16) -> Mesh {
	vbuf := sg.make_buffer({
		data = {
			ptr = raw_data(vertices),
			size = len(vertices) * size_of(Vertex),
		},
	})
	ibuf := sg.make_buffer({
		usage = {index_buffer = true},
		data = {ptr = raw_data(indices), size = len(indices) * size_of(u16)},
	})

	wireframe_indices := mesh_make_line_indices(indices)
	defer delete(wireframe_indices)

	wibuf := sg.make_buffer({
		usage = {index_buffer = true},
		data = {
			ptr = raw_data(wireframe_indices),
			size = len(wireframe_indices) * size_of(u16),
		},
	})

	return Mesh {
		vertex_buffer = vbuf,
		index_buffer = ibuf,
		index_count = i32(len(indices)),
		wire_index_buffer = wibuf,
		wire_index_count = i32(len(wireframe_indices)),
	}
}

mesh_destroy :: proc(m: ^Mesh) {
	sg.destroy_buffer(m.vertex_buffer)
	sg.destroy_buffer(m.index_buffer)
	sg.destroy_buffer(m.wire_index_buffer)

	m.vertex_buffer = {}
	m.index_buffer = {}
	m.wire_index_buffer = {}

	m.index_count = 0
	m.wire_index_count = 0
}

mesh_make_box :: proc(
	half_size: [3]f32 = {1.0, 1.0, 1.0},
	color: [4]u8 = MESH_DEFAULT_VERTEX_COLOR,
) -> Mesh {
	//odinfmt: disable
	// cube vertex buffer
    vertices := [?]Vertex {
        // pos                 color                 uvs
        { {-1.0, -1.0, -1.0},  {255, 255, 255, 255}, {    0,     0} },
        { { 1.0, -1.0, -1.0},  {255, 255, 255, 255}, {32767,     0} },
        { { 1.0,  1.0, -1.0},  {255, 255, 255, 255}, {32767, 32767} },
        { {-1.0,  1.0, -1.0},  {255, 255, 255, 255}, {    0, 32767} },
        { {-1.0, -1.0,  1.0},  {255, 255, 255, 255}, {    0,     0} },
        { { 1.0, -1.0,  1.0},  {255, 255, 255, 255}, {32767,     0} },
        { { 1.0,  1.0,  1.0},  {255, 255, 255, 255}, {32767, 32767} },
        { {-1.0,  1.0,  1.0},  {255, 255, 255, 255}, {    0, 32767} },
        { {-1.0, -1.0, -1.0},  {255, 255, 255, 255}, {    0,     0} },
        { {-1.0,  1.0, -1.0},  {255, 255, 255, 255}, {32767,     0} },
        { {-1.0,  1.0,  1.0},  {255, 255, 255, 255}, {32767, 32767} },
        { {-1.0, -1.0,  1.0},  {255, 255, 255, 255}, {    0, 32767} },
        { { 1.0, -1.0, -1.0},  {255, 255, 255, 255}, {    0,     0} },
        { { 1.0,  1.0, -1.0},  {255, 255, 255, 255}, {32767,     0} },
        { { 1.0,  1.0,  1.0},  {255, 255, 255, 255}, {32767, 32767} },
        { { 1.0, -1.0,  1.0},  {255, 255, 255, 255}, {    0, 32767} },
        { {-1.0, -1.0, -1.0},  {255, 255, 255, 255}, {    0,     0} },
        { {-1.0, -1.0,  1.0},  {255, 255, 255, 255}, {32767,     0} },
        { { 1.0, -1.0,  1.0},  {255, 255, 255, 255}, {32767, 32767} },
        { { 1.0, -1.0, -1.0},  {255, 255, 255, 255}, {    0, 32767} },
        { {-1.0,  1.0, -1.0},  {255, 255, 255, 255}, {    0,     0} },
        { {-1.0,  1.0,  1.0},  {255, 255, 255, 255}, {32767,     0} },
        { { 1.0,  1.0,  1.0},  {255, 255, 255, 255}, {32767, 32767} },
        { { 1.0,  1.0, -1.0},  {255, 255, 255, 255}, {    0, 32767} },
    }
    // create an index buffer for the cube
    indices := [?]u16 {
        0, 1, 2,  0, 2, 3,
        6, 5, 4,  7, 6, 4,
        8, 9, 10,  8, 10, 11,
        14, 13, 12,  15, 14, 12,
        16, 17, 18,  16, 18, 19,
        22, 21, 20,  23, 22, 20,
    }
	//odinfmt: enable

	for &v in vertices {
		v.position *= half_size
		v.color = color
	}

	return mesh_make_from_data(vertices[:], indices[:])
}

mesh_make_plane :: proc(
	size: [2]f32 = {10.0, 10.0},
	subdivisions: [2]int = {1, 1},
	color: [4]u8 = MESH_DEFAULT_VERTEX_COLOR,
) -> Mesh {
	sub_x := max(subdivisions.x, 1)
	sub_z := max(subdivisions.y, 1)

	vert_count := (sub_x + 1) * (sub_z + 1)
	idx_count := sub_x * sub_z * 6

	vertices := make([dynamic]Vertex, 0, vert_count)
	indices := make([dynamic]u16, 0, idx_count)
	defer delete(vertices)
	defer delete(indices)

	for z in 0 ..= sub_z {
		fz := f32(z) / f32(sub_z)
		pz := (fz - 0.5) * size.y
		v_uv := u16(fz * 32767.0)

		for x in 0 ..= sub_x {
			fx := f32(x) / f32(sub_x)
			px := (fx - 0.5) * size.x
			u_uv := u16(fx * 32767.0)

			append(
				&vertices,
				Vertex{
					position = {px, 0, pz},
					color = color,
					uv = {u_uv, v_uv},
				},
			)
		}
	}

	stride := u16(sub_x + 1)
	for z in 0 ..< sub_z {
		for x in 0 ..< sub_x {
			uz := u16(z)
			ux := u16(x)

			i0 := uz * stride + ux
			i1 := (uz + 1) * stride + ux
			i2 := (uz + 1) * stride + (ux + 1)
			i3 := uz * stride + (ux + 1)

			append(&indices, i0, i1, i2, i0, i2, i3)
		}
	}

	return mesh_make_from_data(vertices[:], indices[:])
}

mesh_make_sphere :: proc(
	radius: f32 = 1.0,
	rings: int = 16,
	sectors: int = 16,
	color: [4]u8 = MESH_DEFAULT_VERTEX_COLOR,
) -> Mesh {
	r_count := max(rings, 3)
	s_count := max(sectors, 3)

	vert_count := (r_count + 1) * (s_count + 1)
	idx_count := r_count * s_count * 6

	vertices := make([dynamic]Vertex, 0, vert_count)
	indices := make([dynamic]u16, 0, idx_count)
	defer delete(vertices)
	defer delete(indices)

	for r in 0 ..= r_count {
		theta := (f32(r) / f32(r_count)) * math.PI
		sin_theta := math.sin(theta)
		cos_theta := math.cos(theta)
		v_uv := u16((f32(r) / f32(r_count)) * 32767.0)

		for s in 0 ..= s_count {
			phi := (f32(s) / f32(s_count)) * (2.0 * math.PI)
			sin_phi := math.sin(phi)
			cos_phi := math.cos(phi)
			u_uv := u16((f32(s) / f32(s_count)) * 32767.0)

			px := radius * sin_theta * cos_phi
			py := radius * cos_theta
			pz := radius * sin_theta * sin_phi

			append(
				&vertices,
				Vertex{
					position = {px, py, pz},
					color = color,
					uv = {u_uv, v_uv},
				},
			)
		}
	}

	stride := u16(s_count + 1)
	for r in 0 ..< r_count {
		for s in 0 ..< s_count {
			ur := u16(r)
			us := u16(s)

			i0 := ur * stride + us
			i1 := (ur + 1) * stride + us
			i2 := (ur + 1) * stride + (us + 1)
			i3 := ur * stride + (us + 1)

			append(&indices, i0, i1, i2, i0, i2, i3)
		}
	}

	return mesh_make_from_data(vertices[:], indices[:])
}

mesh_make_cylinder :: proc(
	radius: f32 = 0.5,
	height: f32 = 2.0,
	sectors: int = 16,
	color: [4]u8 = MESH_DEFAULT_VERTEX_COLOR,
) -> Mesh {
	s_count := max(sectors, 3)
	half_h := height * 0.5

	vertices := make([dynamic]Vertex, 0, (s_count + 1) * 4 + 2)
	indices := make([dynamic]u16, 0, s_count * 12)
	defer delete(vertices)
	defer delete(indices)

	for s in 0 ..= s_count {
		phi := (f32(s) / f32(s_count)) * (2.0 * math.PI)
		sin_phi := math.sin(phi)
		cos_phi := math.cos(phi)
		u_uv := u16((f32(s) / f32(s_count)) * 32767.0)

		px := radius * cos_phi
		pz := radius * sin_phi

		append(
			&vertices,
			Vertex{position = {px, half_h, pz}, color = color, uv = {u_uv, 0}},
		)
		append(
			&vertices,
			Vertex{
				position = {px, -half_h, pz},
				color = color,
				uv = {u_uv, 32767},
			},
		)
	}

	for s in 0 ..< s_count {
		us := u16(s)
		i0 := us * 2 + 0
		i1 := us * 2 + 1
		i2 := (us + 1) * 2 + 1
		i3 := (us + 1) * 2 + 0

		append(&indices, i0, i1, i2, i0, i2, i3)
	}

	top_center_idx := u16(len(vertices))
	append(
		&vertices,
		Vertex{position = {0, half_h, 0}, color = color, uv = {16384, 16384}},
	)
	top_start := u16(len(vertices))
	for s in 0 ..= s_count {
		phi := (f32(s) / f32(s_count)) * (2.0 * math.PI)
		px := radius * math.cos(phi)
		pz := radius * math.sin(phi)
		u_uv := u16(((px / radius) * 0.5 + 0.5) * 32767.0)
		v_uv := u16(((pz / radius) * 0.5 + 0.5) * 32767.0)
		append(
			&vertices,
			Vertex{
				position = {px, half_h, pz},
				color = color,
				uv = {u_uv, v_uv},
			},
		)
	}
	for s in 0 ..< s_count {
		us := u16(s)
		append(&indices, top_center_idx, top_start + us, top_start + us + 1)
	}

	bot_center_idx := u16(len(vertices))
	append(
		&vertices,
		Vertex{position = {0, -half_h, 0}, color = color, uv = {16384, 16384}},
	)
	bot_start := u16(len(vertices))
	for s in 0 ..= s_count {
		phi := (f32(s) / f32(s_count)) * (2.0 * math.PI)
		px := radius * math.cos(phi)
		pz := radius * math.sin(phi)
		u_uv := u16(((px / radius) * 0.5 + 0.5) * 32767.0)
		v_uv := u16(((pz / radius) * 0.5 + 0.5) * 32767.0)
		append(
			&vertices,
			Vertex{
				position = {px, -half_h, pz},
				color = color,
				uv = {u_uv, v_uv},
			},
		)
	}
	for s in 0 ..< s_count {
		us := u16(s)
		append(&indices, bot_center_idx, bot_start + us + 1, bot_start + us)
	}

	return mesh_make_from_data(vertices[:], indices[:])
}

mesh_make_capsule :: proc(
	radius: f32 = 0.5,
	height: f32 = 1.0,
	rings: int = 8,
	sectors: int = 16,
	color: [4]u8 = MESH_DEFAULT_VERTEX_COLOR,
) -> Mesh {
	r_count := max(rings, 4)
	if r_count % 2 != 0 do r_count += 1
	s_count := max(sectors, 3)
	half_h := height * 0.5

	vert_count := (r_count + 1) * (s_count + 1)
	idx_count := r_count * s_count * 6

	vertices := make([dynamic]Vertex, 0, vert_count)
	indices := make([dynamic]u16, 0, idx_count)
	defer delete(vertices)
	defer delete(indices)

	for r in 0 ..= r_count {
		theta := (f32(r) / f32(r_count)) * math.PI
		sin_theta := math.sin(theta)
		cos_theta := math.cos(theta)
		v_uv := u16((f32(r) / f32(r_count)) * 32767.0)

		y_offset := r <= (r_count / 2) ? half_h : -half_h

		for s in 0 ..= s_count {
			phi := (f32(s) / f32(s_count)) * (2.0 * math.PI)
			sin_phi := math.sin(phi)
			cos_phi := math.cos(phi)
			u_uv := u16((f32(s) / f32(s_count)) * 32767.0)

			px := radius * sin_theta * cos_phi
			py := radius * cos_theta + y_offset
			pz := radius * sin_theta * sin_phi

			append(
				&vertices,
				Vertex{
					position = {px, py, pz},
					color = color,
					uv = {u_uv, v_uv},
				},
			)
		}
	}

	stride := u16(s_count + 1)
	for r in 0 ..< r_count {
		for s in 0 ..< s_count {
			ur := u16(r)
			us := u16(s)

			i0 := ur * stride + us
			i1 := (ur + 1) * stride + us
			i2 := (ur + 1) * stride + (us + 1)
			i3 := ur * stride + (us + 1)

			append(&indices, i0, i1, i2, i0, i2, i3)
		}
	}

	return mesh_make_from_data(vertices[:], indices[:])
}

mesh_make_line_indices :: proc(tri_indices: []u16) -> []u16 {
	tri_count := len(tri_indices) / 3
	line_indices := make([]u16, tri_count * 6)

	for i in 0 ..< tri_count {
		i0 := tri_indices[i * 3 + 0]
		i1 := tri_indices[i * 3 + 1]
		i2 := tri_indices[i * 3 + 2]

		line_indices[i * 6 + 0] = i0
		line_indices[i * 6 + 1] = i1
		line_indices[i * 6 + 2] = i1
		line_indices[i * 6 + 3] = i2
		line_indices[i * 6 + 4] = i2
		line_indices[i * 6 + 5] = i0
	}

	return line_indices
}
