package game

import "core:math"
import "core:math/linalg"
import gltf "glTF2"

Transform :: struct {
	translation: [3]f32,
	rotation:    quaternion128,
	scale:       [3]f32,
}

transform_default :: proc() -> Transform {
	return {
		translation = {0, 0, 0},
		rotation    = linalg.QUATERNIONF32_IDENTITY,
		scale       = {1, 1, 1},
	}
}

transform_to_matrix :: proc(t: Transform) -> matrix[4, 4]f32 {
	translate_mat := linalg.matrix4_translate_f32(t.translation)
	rotate_mat    := linalg.matrix4_from_quaternion(t.rotation)
	scale_mat     := linalg.matrix4_scale_f32(t.scale)
	return translate_mat * rotate_mat * scale_mat
}

Model_Node :: struct {
	name:        string,
	parent:      int,
	children:    [dynamic]int,
	base_trs:    Transform,
	local_trs:   Transform,
	global_mat:  matrix[4, 4]f32,
	mesh_index:  Maybe(int),
	skin_index:  Maybe(int),
}

Model_Mesh_Kind :: enum {
	Rigid,
	Skinned,
}

Model_Mesh_Part :: struct {
	kind:         Model_Mesh_Kind,
	rigid:        Mesh,
	skinned:      Skinned_Mesh,
	material_id:  i32,
}

Model_Skin :: struct {
	joints:                 [dynamic]int,
	inverse_bind_matrices:  [dynamic]matrix[4, 4]f32,
	bone_matrices:          [dynamic]matrix[4, 4]f32,
}

Anim_Path :: enum {
	Translation,
	Rotation,
	Scale,
}

Anim_Channel :: struct {
	node_index:   int,
	path:         Anim_Path,
	timestamps:   [dynamic]f32,
	translations: [dynamic][3]f32,
	rotations:    [dynamic]quaternion128,
	scales:       [dynamic][3]f32,
}

Model_Animation :: struct {
	name:     string,
	duration: f32,
	channels: [dynamic]Anim_Channel,
}

Animation_Loop_Mode :: enum {
	Hold,
	Once,
	Loop,
}

Model :: struct {
	nodes:                 [dynamic]Model_Node,
	meshes:                [dynamic]Model_Mesh_Part,
	skins:                 [dynamic]Model_Skin,
	animations:            [dynamic]Model_Animation,
	gltf_data:             ^gltf.Data,
	current_animation:     int,
	current_time:          f32,
	is_animating:          bool,
	loop_mode:             Animation_Loop_Mode,
}

Model_Attribute :: enum {
	Position,
	UV,
	Joints,
	Weights,
}

MODEL_ATTRIBUTES :: [Model_Attribute]string {
	.Position = "POSITION",
	.UV       = "TEXCOORD_0",
	.Joints   = "JOINTS_0",
	.Weights  = "WEIGHTS_0",
}

model_load_from_memory :: proc(file_data: []byte) -> Model {
	model: Model = {
		nodes      = make([dynamic]Model_Node),
		meshes     = make([dynamic]Model_Mesh_Part),
		skins      = make([dynamic]Model_Skin),
		animations = make([dynamic]Model_Animation),
	}

	gtlf_data, err := gltf.parse(file_data, {is_glb = true})
	assert(err == nil)
	model.gltf_data = gtlf_data

	for &m in model.gltf_data.meshes {
		for &primitive in m.primitives {
			positions := gltf.buffer_slice(model.gltf_data, primitive.attributes[MODEL_ATTRIBUTES[.Position]]).([][3]f32)
			vert_count := len(positions)

			uv_raw := gltf.buffer_slice(model.gltf_data, primitive.attributes[MODEL_ATTRIBUTES[.UV]])
			uvs: [][2]f32
			#partial switch u in uv_raw {
			case [][2]f32:
				uvs = u
			}

			indices := gltf.buffer_slice(model.gltf_data, primitive.indices.?).([]u16)

			has_joints := MODEL_ATTRIBUTES[.Joints] in primitive.attributes
			has_weights := MODEL_ATTRIBUTES[.Weights] in primitive.attributes

			if has_joints && has_weights {
				vertices := make([]Skinned_Vertex, vert_count)
				defer delete(vertices)

				joints_data := gltf.buffer_slice(model.gltf_data, primitive.attributes[MODEL_ATTRIBUTES[.Joints]])
				weights_data := gltf.buffer_slice(model.gltf_data, primitive.attributes[MODEL_ATTRIBUTES[.Weights]])

				for i in 0 ..< vert_count {
					vertices[i].position = positions[i]
					vertices[i].color = MESH_DEFAULT_VERTEX_COLOR
					if len(uvs) > i {
						vertices[i].uv = cast([2]u16)[2]f32{uvs[i].x * 32767, uvs[i].y * 32767}
					}

					#partial switch j in joints_data {
					case [][4]u8:
						vertices[i].joints = {f32(j[i].x), f32(j[i].y), f32(j[i].z), f32(j[i].w)}
					case [][4]u16:
						vertices[i].joints = {f32(j[i].x), f32(j[i].y), f32(j[i].z), f32(j[i].w)}
					}

					#partial switch w in weights_data {
					case [][4]f32:
						vertices[i].weights = w[i]
					case [][4]u8:
						vertices[i].weights = {f32(w[i].x) / 255.0, f32(w[i].y) / 255.0, f32(w[i].z) / 255.0, f32(w[i].w) / 255.0}
					case [][4]u16:
						vertices[i].weights = {f32(w[i].x) / 65535.0, f32(w[i].y) / 65535.0, f32(w[i].z) / 65535.0, f32(w[i].w) / 65535.0}
					}
				}

				part: Model_Mesh_Part = {
					kind = .Skinned,
					skinned = skinned_mesh_make_from_data(vertices, indices),
				}
				append(&model.meshes, part)
			} else {
				vertices := make([]Vertex, vert_count)
				defer delete(vertices)

				for i in 0 ..< vert_count {
					vertices[i].position = positions[i]
					vertices[i].color = MESH_DEFAULT_VERTEX_COLOR
					if len(uvs) > i {
						vertices[i].uv = cast([2]u16)[2]f32{uvs[i].x * 32767, uvs[i].y * 32767}
					}
				}

				part: Model_Mesh_Part = {
					kind = .Rigid,
					rigid = mesh_make_from_data(vertices, indices),
				}
				append(&model.meshes, part)
			}
		}
	}

	for &node in model.gltf_data.nodes {
		m_node: Model_Node = {
			name = node.name.? or_else "",
			parent = -1,
			children = make([dynamic]int),
			base_trs = transform_default(),
			local_trs = transform_default(),
			global_mat = 1,
			mesh_index = int(node.mesh.?) if node.mesh != nil else nil,
			skin_index = int(node.skin.?) if node.skin != nil else nil,
		}

		m_node.base_trs.translation = node.translation
		m_node.base_trs.scale = node.scale
		rot := node.rotation
		if rot != {} {
			m_node.base_trs.rotation = quaternion(w = rot.w, x = rot.x, y = rot.y, z = rot.z)
		}
		m_node.local_trs = m_node.base_trs

		for c in node.children {
			append(&m_node.children, int(c))
		}

		append(&model.nodes, m_node)
	}

	for i in 0 ..< len(model.nodes) {
		for child_idx in model.nodes[i].children {
			if child_idx >= 0 && child_idx < len(model.nodes) {
				model.nodes[child_idx].parent = i
			}
		}
	}

	for &skin in model.gltf_data.skins {
		m_skin: Model_Skin = {
			joints = make([dynamic]int),
			inverse_bind_matrices = make([dynamic]matrix[4, 4]f32),
			bone_matrices = make([dynamic]matrix[4, 4]f32),
		}

		for j in skin.joints {
			append(&m_skin.joints, int(j))
			append(&m_skin.bone_matrices, 1)
		}

		if skin.inverse_bind_matrices != nil {
			ibm_slice := gltf.buffer_slice(model.gltf_data, skin.inverse_bind_matrices.?).([]matrix[4, 4]f32)
			for ibm in ibm_slice {
				append(&m_skin.inverse_bind_matrices, ibm)
			}
		} else {
			for _ in skin.joints {
				append(&m_skin.inverse_bind_matrices, 1)
			}
		}

		append(&model.skins, m_skin)
	}

	for &anim in model.gltf_data.animations {
		m_anim: Model_Animation = {
			name = anim.name.? or_else "",
			duration = 0,
			channels = make([dynamic]Anim_Channel),
		}

		for &ch in anim.channels {
			if ch.target.node == nil do continue

			sampler := anim.samplers[ch.sampler]
			timestamps := gltf.buffer_slice(model.gltf_data, sampler.input).([]f32)

			channel: Anim_Channel = {
				node_index = int(ch.target.node.?),
				timestamps = make([dynamic]f32),
				translations = make([dynamic][3]f32),
				rotations = make([dynamic]quaternion128),
				scales = make([dynamic][3]f32),
			}

			for t in timestamps {
				append(&channel.timestamps, t)
				if t > m_anim.duration {
					m_anim.duration = t
				}
			}

			#partial switch ch.target.path {
			case .Translation:
				channel.path = .Translation
				values := gltf.buffer_slice(model.gltf_data, sampler.output).([][3]f32)
				for v in values {
					append(&channel.translations, v)
				}
			case .Rotation:
				channel.path = .Rotation
				values := gltf.buffer_slice(model.gltf_data, sampler.output).([][4]f32)
				for v in values {
					append(&channel.rotations, quaternion(w = v.w, x = v.x, y = v.y, z = v.z))
				}
			case .Scale:
				channel.path = .Scale
				values := gltf.buffer_slice(model.gltf_data, sampler.output).([][3]f32)
				for v in values {
					append(&channel.scales, v)
				}
			}

			append(&m_anim.channels, channel)
		}

		append(&model.animations, m_anim)
	}

	model_solve_hierarchy(&model)
	return model
}

model_destroy :: proc(model: ^Model) {
	for &m in model.meshes {
		#partial switch m.kind {
		case .Rigid:
			mesh_destroy(&m.rigid)
		case .Skinned:
			skinned_mesh_destroy(&m.skinned)
		}
	}
	delete(model.meshes)

	for &n in model.nodes {
		delete(n.children)
	}
	delete(model.nodes)

	for &s in model.skins {
		delete(s.joints)
		delete(s.inverse_bind_matrices)
		delete(s.bone_matrices)
	}
	delete(model.skins)

	for &a in model.animations {
		for &ch in a.channels {
			delete(ch.timestamps)
			delete(ch.translations)
			delete(ch.rotations)
			delete(ch.scales)
		}
		delete(a.channels)
	}
	delete(model.animations)

	gltf.unload(model.gltf_data)
}

model_play_animation :: proc(model: ^Model, anim_index: int, loop: Animation_Loop_Mode = .Hold) {
	if anim_index >= 0 && anim_index < len(model.animations) {
		model.current_animation = anim_index
		model.current_time = 0
		model.is_animating = true
		model.loop_mode = loop
	}
}

model_play_animation_by_name :: proc(model: ^Model, name: string, loop: Animation_Loop_Mode = .Loop) -> bool {
	for anim, idx in model.animations {
		if anim.name == name {
			model_play_animation(model, idx, loop)
			return true
		}
	}
	return false
}

model_update_animation :: proc(model: ^Model, dt: f32) {
	if !model.is_animating || len(model.animations) == 0 do return

	anim := &model.animations[model.current_animation]
	if anim.duration <= 0 do return

	model.current_time += dt

	if model.current_time >= anim.duration {
		switch model.loop_mode {
		case .Loop:
			model.current_time = math.mod(model.current_time, anim.duration)
		case .Once:
			model.current_time = anim.duration
			model.is_animating = false
		case .Hold:
			model.current_time = anim.duration
		}
	}

	model_sample_animation(model, model.current_animation, model.current_time)
}

model_sample_animation :: proc(model: ^Model, anim_index: int, time: f32) {
	if anim_index < 0 || anim_index >= len(model.animations) do return
	anim := &model.animations[anim_index]

	for &node in model.nodes {
		node.local_trs = node.base_trs
	}

	for &ch in anim.channels {
		if len(ch.timestamps) == 0 do continue
		if ch.node_index < 0 || ch.node_index >= len(model.nodes) do continue

		node := &model.nodes[ch.node_index]

		if len(ch.timestamps) == 1 {
			#partial switch ch.path {
			case .Translation:
				if len(ch.translations) > 0 do node.local_trs.translation = ch.translations[0]
			case .Rotation:
				if len(ch.rotations) > 0 do node.local_trs.rotation = ch.rotations[0]
			case .Scale:
				if len(ch.scales) > 0 do node.local_trs.scale = ch.scales[0]
			}
			continue
		}

		idx := 0
		for i in 0 ..< len(ch.timestamps) - 1 {
			if time >= ch.timestamps[i] && time <= ch.timestamps[i + 1] {
				idx = i
				break
			}
			if time > ch.timestamps[i + 1] {
				idx = i + 1
			}
		}

		if idx >= len(ch.timestamps) - 1 {
			idx = len(ch.timestamps) - 2
		}

		t0 := ch.timestamps[idx]
		t1 := ch.timestamps[idx + 1]
		factor: f32 = 0
		if t1 > t0 {
			factor = clamp((time - t0) / (t1 - t0), 0, 1)
		}

		#partial switch ch.path {
		case .Translation:
			if len(ch.translations) > idx + 1 {
				node.local_trs.translation = linalg.lerp(ch.translations[idx], ch.translations[idx + 1], factor)
			}
		case .Rotation:
			if len(ch.rotations) > idx + 1 {
				node.local_trs.rotation = linalg.quaternion_nlerp(ch.rotations[idx], ch.rotations[idx + 1], factor)
			}
		case .Scale:
			if len(ch.scales) > idx + 1 {
				node.local_trs.scale = linalg.lerp(ch.scales[idx], ch.scales[idx + 1], factor)
			}
		}
	}

	model_solve_hierarchy(model)
}

model_solve_hierarchy :: proc(model: ^Model) {
	for i in 0 ..< len(model.nodes) {
		if model.nodes[i].parent == -1 {
			model_solve_node_recursive(model, i, 1)
		}
	}

	for &skin in model.skins {
		for i in 0 ..< len(skin.joints) {
			joint_node_idx := skin.joints[i]
			if joint_node_idx >= 0 && joint_node_idx < len(model.nodes) {
				skin.bone_matrices[i] = model.nodes[joint_node_idx].global_mat * skin.inverse_bind_matrices[i]
			}
		}
	}
}

@(private = "file")
model_solve_node_recursive :: proc(model: ^Model, node_index: int, parent_mat: matrix[4, 4]f32) {
	node := &model.nodes[node_index]
	local_mat := transform_to_matrix(node.local_trs)
	node.global_mat = parent_mat * local_mat

	for child_idx in node.children {
		if child_idx >= 0 && child_idx < len(model.nodes) {
			model_solve_node_recursive(model, child_idx, node.global_mat)
		}
	}
}

model_draw :: proc(
	model: Model,
	camera: ^Camera,
	position: [3]f32 = {0, 0, 0},
	rotation: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
) {
	base_mat := linalg.matrix4_translate_f32(position) * linalg.matrix4_from_quaternion(rotation)

	for node in model.nodes {
		if node.mesh_index != nil {
			mesh_idx := node.mesh_index.?
			if mesh_idx >= 0 && mesh_idx < len(model.meshes) {
				part := model.meshes[mesh_idx]
				#partial switch part.kind {
				case .Rigid:
					final_mat := base_mat * node.global_mat
					draw_mesh_matrix(part.rigid, final_mat, camera)
				case .Skinned:
					skin_idx := node.skin_index.? or_else 0
					if skin_idx >= 0 && skin_idx < len(model.skins) {
						skin := model.skins[skin_idx]
						draw_skinned_mesh_matrix(part.skinned, base_mat, skin.bone_matrices[:], camera)
					}
				}
			}
		}
	}
}
