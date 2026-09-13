package data

Damage_Type :: enum {
	BULLET,
	MELEE,
	EXPLOSION,
	TOUCH,
}

Projectile_Model :: enum {
	HITSCAN,
	PROJECTILE,
}

Hit_Info :: struct {
	damage:       f32,
	damage_type:  Damage_Type,
	position:     [3]f32,
	normal:       [3]f32,
	direction:    [3]f32,
	impact_force: f32,
}
