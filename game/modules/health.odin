package modules
import d "../data"

Health :: struct {
	current:     f32,
	max:         f32,
	invincible:  bool,
	flash_timer: f32,
	last_hit:    d.Hit_Info,
}

health_take_hit :: proc(h: ^Health, hit: d.Hit_Info) -> (died: bool) {
	if h.current <= 0 || h.invincible do return false
	h.last_hit = hit
	h.current -= hit.damage
	h.flash_timer = 0.1
	if h.current <= 0 {
		h.current = 0
		return true
	}
	return false
}
