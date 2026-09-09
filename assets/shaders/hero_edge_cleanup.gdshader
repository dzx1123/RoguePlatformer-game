shader_type canvas_item;
// Neutral matte cleanup. Interior highlights retain their authored colour.
uniform float matte_radius = 3.0;
varying vec4 sprite_tint;
void vertex() { sprite_tint = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float edge_alpha = 1.0;
	for (int ring = 1; ring <= 3; ring++) {
		float radius = float(ring) * matte_radius;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				if (x != 0 || y != 0) {
					edge_alpha = min(edge_alpha, texture(TEXTURE, UV + vec2(float(x), float(y)) * radius * TEXTURE_PIXEL_SIZE).a);
				}
			}
		}
	}
	float low = min(source.r, min(source.g, source.b));
	float high = max(source.r, max(source.g, source.b));
	float matte = (1.0 - smoothstep(0.18, 0.35, high - low)) * smoothstep(0.28, 0.52, low);
	// Only the outermost hair edge is matte; do not turn white hair into a helmet.
	if (UV.y < 0.44) {
		edge_alpha = min(min(texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a, texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a), min(texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a));
	}
	source.rgb = mix(source.rgb, vec3(0.07, 0.105, 0.16), matte * (1.0 - smoothstep(0.05, 0.8, edge_alpha)));
	COLOR = source * sprite_tint;
}