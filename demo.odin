package main

import stbtt "vendor:stb/truetype"

main :: proc() {
	font := #load("assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf")
	atlas := make([dynamic]byte, 512 * 512)
	defer delete(atlas)
	bakedchar: stbtt.bakedchar
	stbtt.BakeFontBitmap(
		raw_data(font),
		0,
		16,
		raw_data(atlas),
		512,
		512,
		32,
		96,
		&bakedchar,
	)

}
