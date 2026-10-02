shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D depth_texture : hint_depth_texture;

// Water colors
uniform vec4 shallow_color : source_color = vec4(0.15, 0.65, 0.95, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.15, 0.35, 1.0);

// Foam
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_distance = 20.0;
uniform float foam_strength = 2.0;
uniform float foam_scale = 2.0;
uniform float foam_speed = 0.15;

// Waves
uniform float wave_height = 0.15;
uniform float wave_speed = 0.15;
uniform float wave_scale = 0.05;

// Highlights
uniform float fresnel_strength = 3.0;
uniform vec4 edge_color : source_color = vec4(0.8, 1.0, 1.0, 1.0);

varying vec3 world_pos;

void vertex()
{
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float wave1 =
		sin(world_pos.x * wave_scale + TIME * wave_speed);

	float wave2 =
		cos(world_pos.z * wave_scale * 0.7 - TIME * wave_speed);

	float wave3 =
		sin((world_pos.x + world_pos.z) * wave_scale * 0.5
		+ TIME * wave_speed * 0.5);

	VERTEX.y += (wave1 + wave2 + wave3) * wave_height;
}

void fragment()
{
	// Base water color
	float fresnel =
		pow(
			1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0),
			fresnel_strength
		);

	vec3 water_color =
		mix(
			deep_color.rgb,
			shallow_color.rgb,
			fresnel
		);

	// Scene depth
	float raw_depth = texture(depth_texture, SCREEN_UV).r;

	vec3 ndc = vec3(
		SCREEN_UV * 2.0 - 1.0,
		raw_depth
	);

	vec4 world =
		INV_VIEW_MATRIX *
		INV_PROJECTION_MATRIX *
		vec4(ndc, 1.0);

	world.xyz /= world.w;

	float scene_height = world.y;
	float water_height = world_pos.y;

	float edge =
		1.0 -
		smoothstep(
			0.0,
			foam_distance,
			abs(scene_height - water_height)
		);

	// Large animated foam pattern
	float foam_pattern =
		sin(world_pos.x * foam_scale + TIME * foam_speed)
		*
		cos(world_pos.z * foam_scale * 0.8 - TIME * foam_speed);

	foam_pattern =
		smoothstep(
			-0.2,
			0.2,
			foam_pattern
		);

	vec3 foam =
		foam_color.rgb
		*
		edge
		*
		foam_pattern
		*
		foam_strength;

	ALBEDO = water_color + foam;

	EMISSION =
		edge_color.rgb
		*
		fresnel
		*
		0.4;

	ROUGHNESS = 0.05;
	METALLIC = 0.0;
}