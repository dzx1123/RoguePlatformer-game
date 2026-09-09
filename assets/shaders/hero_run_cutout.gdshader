shader_type canvas_item;

// The run atlas has neutral backdrop trapped inside arm/leg openings.
// Hair is above this body band. Do not depend on connection to outer alpha:
// enclosed white islands must become transparent as well.
varying vec4 sprite_tint;
void vertex() { sprite_tint = COLOR; }

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float low = min(source.r, min(source.g, source.b));
	float high = max(source.r, max(source.g, source.b));
	float body_band = step(0.51, UV.y);
	float neutral = 1.0 - smoothstep(0.10, 0.22, high - low);
	float white_backdrop = smoothstep(0.64, 0.83, low) * neutral * body_band;
	source.a *= 1.0 - white_backdrop;
	float adjacent_alpha = 1.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec4 neighbor = texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE);
			float n_low = min(neighbor.r, min(neighbor.g, neighbor.b));
			float n_high = max(neighbor.r, max(neighbor.g, neighbor.b));
			float n_matte = smoothstep(0.64, 0.83, n_low) * (1.0 - smoothstep(0.10, 0.22, n_high - n_low)) * body_band;
			adjacent_alpha = min(adjacent_alpha, neighbor.a * (1.0 - n_matte));
		}
	}
	float fringe = (1.0 - adjacent_alpha) * neutral * smoothstep(0.30, 0.62, low) * body_band;
	source.rgb = mix(source.rgb, vec3(0.07, 0.105, 0.16), fringe);
	COLOR = source * sprite_tint;
}
