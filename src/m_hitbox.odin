package game
import b3 "vendor:box3d"

M_Hitbox :: struct {
	multiplier: f32,
	health:     ^M_Health,
}

m_hitbox_make :: proc(
	health: ^M_Health,
	damage_multiplier: f32 = 1.,
) -> M_Hitbox {
	return {multiplier = damage_multiplier, health = health}
}

m_hitbox_attach_shape :: proc(body: b3.BodyId, shape: b3.ShapeDef) {
	modified_shape := shape
	modified_shape.isSensor = true

	modified_shape.filter = physics_filter_make()

}

m_hitbox_take_hit :: proc(hitbox: ^M_Hitbox, hit_info: Hit_Info) {
	modified_mit := hit_info
	modified_mit.damage *= hitbox.multiplier

	m_health_take_hit(modified_mit)
}
