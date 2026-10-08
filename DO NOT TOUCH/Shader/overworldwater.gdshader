shader_type spatial;

uniform vec4 water_color : source_color = vec4(0.02, 0.25, 0.35, 1.0);

uniform sampler2D water_normal_01 : hint_normal;

uniform float normal_speed = 0.025;
uniform float normal_tiling = 2.0;

uniform float wave_height = 0.15;
uniform float wave_length = 8.0;
uniform float wave_speed = 1.0;

void vertex()
{
    float k = 6.283185 / wave_length;

    float wave = sin(
        VERTEX.x * k +
        TIME * wave_speed
    );

    VERTEX.y += wave * wave_height;
}

void fragment()
{
    vec2 normal_uv =
        UV * normal_tiling +
        vec2(TIME * normal_speed);

    NORMAL_MAP = texture(
        water_normal_01,
        normal_uv
    ).rgb;

    ALBEDO = water_color.rgb;

    ROUGHNESS = 0.2;
    METALLIC = 0.0;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
