shader_type spatial;
render_mode blend_mix, unshaded;

uniform sampler2D water_texture;
uniform float scroll_speed = 0.05;

void fragment() {
    vec2 uv = UV;
    uv.x += TIME * scroll_speed;

    vec4 tex = texture(water_texture, uv);

    ALBEDO = tex.rgb;
    ALPHA = tex.a;
}
