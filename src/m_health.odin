package game

M_Health :: struct {
	current:    f32,
	max:        f32,
	invincible: bool,
	last_hit:   Hit_Info,
}

m_health_take_hit :: proc(mod: ^M_Health, hit: Hit_Info) -> (died: bool) {
	if mod.current <= 0 || mod.invincible do return false
	mod.last_hit = hit
	mod.current -= hit.damage
	if mod.current <= 0 {
		mod.current = 0
		return true
	}
	return false
}
