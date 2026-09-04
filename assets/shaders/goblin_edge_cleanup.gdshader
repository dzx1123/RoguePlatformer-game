shader_type canvas_item;

// The authored goblin atlases have pale matte pixels at the transparent edge.
// Recolour only neutral edge contamination, not internal teeth/eye highlights.
// Alpha and geometry are preserved so frame registration cannot change.
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float surrounding_alpha = 1.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x != 0 || y != 0) {
				surrounding_alpha = min(surrounding_alpha,
					texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE).a);
			}
		}
	}
	float brightest = max(source.r, max(source.g, source.b));
	float darkest = min(source.r, min(source.g, source.b));
	float neutral_matte = (1.0 - smoothstep(0.10, 0.30, brightest - darkest))
		* smoothstep(0.18, 0.65, darkest);
	float outer_edge = 1.0 - smoothstep(0.10, 0.90, surrounding_alpha);
	source.rgb = mix(source.rgb, vec3(0.12, 0.035, 0.045), neutral_matte * outer_edge);
	COLOR = source * sprite_tint;
}
