package game

Bullet_Config :: struct {}

Bullet :: struct {
	config: Bullet_Config,
}

Projectile :: struct {
	using base: Bullet,
}
