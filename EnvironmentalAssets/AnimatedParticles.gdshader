shader_type spatial;
render_mode unshaded, cull_disabled;

//Add the bubble texture
uniform sampler2D bubble_texture : source_color;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	float frame = floor(TIME * 5.0);
    frame = mod(frame, 2.0);

    vec2 uv = UV;
    uv.x = (uv.x + frame) / 2.0;

    vec4 tex = texture(bubble_texture, uv);

    ALBEDO = tex.rgb;
    ALPHA = tex.a;
}
//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
