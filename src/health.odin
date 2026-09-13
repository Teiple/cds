package game

Health :: struct {
	current:    f32,
	max:        f32,
	invincible: bool,
	last_hit:   Hit_Info,
}

health_take_hit :: proc(h: ^Health, hit: Hit_Info) -> (died: bool) {
	if h.current <= 0 || h.invincible do return false
	h.last_hit = hit
	h.current -= hit.damage
	if h.current <= 0 {
		h.current = 0
		return true
	}
	return false
}
