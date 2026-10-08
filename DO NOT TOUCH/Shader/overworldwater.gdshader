shader_type spatial;

//these are all my exposed variables
//uniform vec4 albedo : source_color = vec4(0.02, 0.22, 0.30, 1.0);
uniform sampler2D water_normal_1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D water_normal_2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_1_strength : hint_range(0.0, 2.0) = 0.8;
uniform float normal_2_strength : hint_range(0.0, 2.0) = 0.5;
uniform float normal_1_scale : hint_range(0.1, 10.0) = 1.5;
uniform float normal_2_scale : hint_range(0.1, 10.0) = 3.0;
uniform float normal_1_speed : hint_range(0.0, 1.0) = 0.025;
uniform float normal_2_speed : hint_range(0.0, 1.0) = 0.018;
uniform float wave_height : hint_range(0.0, 1.0) = 0.12;
uniform float wave_scale : hint_range(0.1, 20.0) = 8.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.18;
uniform float specular : hint_range(0.0, 1.0) = 0.8;
uniform vec4 water_color_1 : source_color = vec4(0.015, 0.18, 0.25, 1.0);
uniform vec4 water_color_2 : source_color = vec4(0.02, 0.28, 0.32, 1.0);
uniform float color_variation : hint_range(0.0, 1.0) = 0.35;

//water has actual mesh deformation.
void vertex() {
    float wave_1 = sin(
        VERTEX.x / wave_scale +
        TIME * wave_speed
    );

    float wave_2 = sin(
        (VERTEX.z + VERTEX.x * 0.5) / (wave_scale * 1.7) +
        TIME * wave_speed * 0.6
    );

    VERTEX.y += (wave_1 + wave_2) * wave_height * 0.5;
}

void fragment() {
    float color_wave = sin(
    VERTEX.x * 0.08 +
    VERTEX.z * 0.06 +
    TIME * 0.05
);

color_wave = color_wave * 0.5 + 0.5;
//Where the two water colors are blended together
vec3 water_color = mix(
    water_color_1.rgb,
    water_color_2.rgb,
    color_wave * color_variation
);

ALBEDO = water_color;

    vec2 normal_uv_1 = UV * normal_1_scale;
    normal_uv_1 += vec2(
        TIME * normal_1_speed,
        TIME * normal_1_speed * 0.5
    );

    vec3 normal_1 = texture(water_normal_1, normal_uv_1).rgb;
    normal_1 = normal_1 * 2.0 - 1.0;
    normal_1.xy *= normal_1_strength;


    vec2 normal_uv_2 = UV * normal_2_scale;
    normal_uv_2 += vec2(
        -TIME * normal_2_speed * 0.7,
        TIME * normal_2_speed
    );

    vec3 normal_2 = texture(water_normal_2, normal_uv_2).rgb;
    normal_2 = normal_2 * 2.0 - 1.0;
    normal_2.xy *= normal_2_strength;


    vec3 combined_normal = normalize(
        vec3(
            normal_1.xy + normal_2.xy,
            1.0
        )
    );

    NORMAL_MAP = combined_normal * 0.5 + 0.5;
	//By default the water looks best when its not rough at all
	//And the white sparkles make it look a bit more interesting
    ROUGHNESS = 0.0;
    SPECULAR = 1.0;
	//The textures are bad though
}
//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
