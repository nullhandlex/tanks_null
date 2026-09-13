shader_type canvas_item;

// Dark masonry veins only. No punched holes — those read as craters.
uniform float ruin : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a >= 0.04 && ruin >= 0.02) {
		float d = clamp(ruin, 0.0, 1.0);
		float v1 = abs(fract(UV.x * 18.0 + sin(UV.y * 28.0) * 0.55) - 0.5);
		float v2 = abs(fract(UV.y * 13.0 + cos(UV.x * 24.0 + 1.1) * 0.42) - 0.5);
		float v3 = abs(fract((UV.x + UV.y) * 16.0 + 0.4) - 0.5);
		float v4 = abs(fract((UV.x * 1.4 - UV.y) * 17.5 + 1.8) - 0.5);
		float v5 = abs(fract(UV.x * 9.0 + UV.y * 21.0 + sin(UV.x * 11.0) * 0.35) - 0.5);
		float v6 = abs(fract((UV.x * 0.6 + UV.y) * 22.0 + 2.7) - 0.5);
		float vein = min(min(v1, v2), min(min(v3, v4), min(v5, v6)));
		float width = 0.0045 + d * 0.01;
		float from_bottom = smoothstep(0.08, 0.92, UV.y + d * 0.7);
		float crack = (1.0 - smoothstep(0.0, width, vein)) * smoothstep(0.02, 0.14, d) * from_bottom;
		col.rgb = mix(col.rgb, vec3(0.05, 0.04, 0.04), crack * 0.94);
	}
	COLOR = col;
}
