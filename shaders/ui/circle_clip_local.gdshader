shader_type canvas_item;

varying vec2 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 center = vec2(71.0, 71.0);
	float a = tex.a * (1.0 - smoothstep(69.5, 71.0, length(v_local - center)));
	if (a <= 0.001) {
		discard;
	}
	COLOR = vec4(tex.rgb, a);
}
