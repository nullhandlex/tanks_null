shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = UV * 2.0 - 1.0;
	float a = tex.a * (1.0 - smoothstep(0.96, 1.0, length(p)));
	if (a <= 0.001) {
		discard;
	}
	COLOR = vec4(tex.rgb, a);
}
