shader_type spatial;
render_mode unshaded;
render_mode cull_disabled;

uniform sampler2D water_texture;
uniform float scroll_speed = 0.05;

void fragment() {
    vec2 uv = UV;

    uv.x += TIME * scroll_speed;

    vec3 water = texture(water_texture, uv).rgb;

    ALBEDO = water;
}
