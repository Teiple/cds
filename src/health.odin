package game

Health :: struct {
	current:    f32,
	max:        f32,
	invincible: bool,
	last_hit:   Hit_Info,
}

health_take_hit :: proc(health: ^Health, hit: Hit_Info) -> (died: bool) {
	if health.current <= 0 || health.invincible do return false
	health.last_hit = hit
	health.current -= hit.damage
	if health.current <= 0 {
		health.current = 0
		return true
	}
	return false
}
