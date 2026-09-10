shader_type canvas_item;
uniform vec4 skin_color : source_color = vec4(0.78, 0.26, 0.20, 1.0);
varying vec4 sprite_tint;
void vertex() { sprite_tint = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// Recolour turquoise skin only, retaining weapon/leather/eyes and original alpha.
	if (source.g > source.r * 1.12 && source.b > source.r * 1.04 && source.g > 0.08) {
		float shade = source.g * 1.65;
		source.rgb = skin_color.rgb * shade;
	}
	COLOR = source * sprite_tint;
}
