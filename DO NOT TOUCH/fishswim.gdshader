shader_type spatial;

uniform sampler2D texture_albedo : source_color;

uniform float time_scale : hint_range(0.0, 5.0) = 1.0;
uniform float side_to_side : hint_range(0.0, 1.0) = 0.1;
uniform float pivot : hint_range(0.0, 1.0) = 0.5;
uniform float wave : hint_range(0.0, 1.0) = 0.2;
uniform float twist : hint_range(0.0, 1.0) = 0.3;
uniform float mask_black : hint_range(0.0, 1.0) = 0.0;
uniform float mask_white : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float time = TIME * time_scale;

	VERTEX.x += cos(time) * side_to_side;
	float pivot_angle = cos(time) * 0.1 * pivot;
	mat2 rotation_matrix = mat2(vec2(cos(pivot_angle), -sin(pivot_angle)), vec2(sin(pivot_angle), cos(pivot_angle)));
	VERTEX.xz = rotation_matrix * VERTEX.xz;

	float body = (VERTEX.z + 1.0) / 2.0;
	VERTEX.x += cos(time + body) * wave;
	float twist_angle = cos(time + body) * 0.3 * twist;
	mat2 twist_matrix = mat2(vec2(cos(twist_angle), -sin(twist_angle)), vec2(sin(twist_angle), cos(twist_angle)));
	VERTEX.xy = twist_matrix * VERTEX.xy;

	float mask = smoothstep(mask_black, mask_white, 1.0 - body);
	VERTEX.x += cos(time + body) * mask * wave;
	VERTEX.xy = mix(VERTEX.xy, twist_matrix * VERTEX.xy, mask);
}

void fragment() {
	ALBEDO = texture(texture_albedo, UV).rgb;
}