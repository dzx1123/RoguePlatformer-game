// Incoming layer is drawn below the outgoing pose. Correct source-over alpha
// so two opaque poses remain opaque instead of fading to 75% at the midpoint.
uniform bool pose_blend_active = false;
uniform sampler2D pose_from_texture : filter_nearest, repeat_disable;
uniform vec2 pose_from_uv_origin = vec2(0.0);
uniform vec2 pose_from_uv_x = vec2(1.0, 0.0);
uniform vec2 pose_from_uv_y = vec2(0.0, 1.0);
uniform float pose_from_opacity = 0.0;
uniform bool pose_from_run_cutout = false;

float pose_blended_alpha(vec2 uv, float alpha) {
	if (!pose_blend_active) { return alpha; }
	vec2 from_uv = pose_from_uv_origin + uv.x * pose_from_uv_x + uv.y * pose_from_uv_y;
	if (any(lessThan(from_uv, vec2(0.0))) || any(greaterThan(from_uv, vec2(1.0)))) {
		return alpha;
	}
	vec4 previous = texture(pose_from_texture, from_uv);
	if (pose_from_run_cutout) {
		float low = min(previous.r, min(previous.g, previous.b));
		float high = max(previous.r, max(previous.g, previous.b));
		float neutral = 1.0 - smoothstep(0.10, 0.22, high - low);
		previous.a *= 1.0 - smoothstep(0.64, 0.83, low) * neutral * step(0.51, from_uv.y);
	}
	return clamp(alpha / max(0.001, 1.0 - previous.a * pose_from_opacity), 0.0, 1.0);
}
