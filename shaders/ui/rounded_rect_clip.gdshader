shader_type canvas_item;

uniform float corner_radius = 32.0;
uniform vec2 rect_size = vec2(346.0, 330.0);

varying vec2 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(v_local - half_size) - (half_size - vec2(corner_radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius;
	float a = tex.a * (1.0 - smoothstep(-1.0, 1.0, d));
	if (a <= 0.001) {
		discard;
	}
	COLOR = vec4(tex.rgb, a);
}
