package game

import "core:math/linalg"
import gltf "glTF2"

Model_Mesh :: struct {
	mesh:        Mesh,
	transform:   matrix[4, 4]f32,
	material_id: i32,
}

Model :: struct {
	meshes:    [dynamic]Model_Mesh,
	gltf_data: ^gltf.Data,
}

Model_Attribute :: enum {
	Position,
	UV,
}

MODEL_ATTRIBUTES :: [Model_Attribute]string {
	.Position = "POSITION",
	.UV       = "TEXCOORD_0",
}

model_make_from_gltf_primitive :: proc(
	data: ^gltf.Data,
	primitive: gltf.Mesh_Primitive,
	color: [4]u8 = MESH_DEFAULT_VERTEX_COLOR,
) -> Mesh {
	positions := gltf.buffer_slice(data, primitive.attributes[MODEL_ATTRIBUTES[.Position]]).([][3]f32)
	uv := gltf.buffer_slice(data, primitive.attributes[MODEL_ATTRIBUTES[.UV]]).([][2]f32)
	assert(len(positions) == len(uv))

	vert_count := len(positions)
	vertices := make([]Vertex, vert_count)
	defer delete(vertices)

	for i in 0 ..< vert_count {
		vertices[i].position = positions[i]
		vertices[i].color = color
		vertices[i].uv = cast([2]u16)[2]f32{uv[i].x * 32767, uv[i].y * 32767}
	}

	indices := gltf.buffer_slice(data, primitive.indices.?).([]u16)

	return mesh_make_from_data(vertices, indices)
}

model_load_from_memory :: proc(file_data: []byte) -> Model {
	model: Model = {
		meshes = make([dynamic]Model_Mesh, 0, 1),
	}

	gtlf_data, err := gltf.parse(file_data, {is_glb = true})
	assert(err == nil)

	model.gltf_data = gtlf_data

	for &m in model.gltf_data.meshes {
		for &primitive in m.primitives {
			m_mesh: Model_Mesh = {
				mesh = model_make_from_gltf_primitive(model.gltf_data, primitive),
				transform = 1,
				material_id = 0,
			}
			append(&model.meshes, m_mesh)
		}
	}

	return model
}

model_destroy :: proc(model: ^Model) {
	gltf.unload(model.gltf_data)
	for &m in model.meshes {
		mesh_destroy(&m.mesh)
	}
	delete(model.meshes)
}

model_draw :: proc(
	model: Model,
	position: [3]f32 = {0, 0, 0},
	rotation: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
) {
	base_mat := linalg.matrix4_translate_f32(position) * linalg.matrix4_from_quaternion(rotation)

	for m in model.meshes {
		final_mat := base_mat * m.transform
		draw_mesh_matrix(m.mesh, final_mat)
	}
}

model_draw_wireframe :: proc(
	model: Model,
	position: [3]f32 = {0, 0, 0},
	rotation: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
) {
	when ODIN_DEBUG {
		base_mat := linalg.matrix4_translate_f32(position) * linalg.matrix4_from_quaternion(rotation)

		for m in model.meshes {
			final_mat := base_mat * m.transform
			draw_mesh_wireframe_matrix(m.mesh, final_mat)
		}
	}
}

