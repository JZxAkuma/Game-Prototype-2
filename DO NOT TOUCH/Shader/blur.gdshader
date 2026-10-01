shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float blur_radius : hint_range(0.0, 10.0) = 2.0;

void fragment()
{
    vec2 p = SCREEN_PIXEL_SIZE * blur_radius;

    vec4 color = vec4(0.0);

    color += texture(screen_texture, SCREEN_UV + vec2(-p.x, -p.y)) * 1.0;
    color += texture(screen_texture, SCREEN_UV + vec2( 0.0, -p.y)) * 2.0;
    color += texture(screen_texture, SCREEN_UV + vec2( p.x, -p.y)) * 1.0;

    color += texture(screen_texture, SCREEN_UV + vec2(-p.x, 0.0)) * 2.0;
    color += texture(screen_texture, SCREEN_UV)                   * 4.0;
    color += texture(screen_texture, SCREEN_UV + vec2( p.x, 0.0)) * 2.0;

    color += texture(screen_texture, SCREEN_UV + vec2(-p.x, p.y)) * 1.0;
    color += texture(screen_texture, SCREEN_UV + vec2( 0.0, p.y)) * 2.0;
    color += texture(screen_texture, SCREEN_UV + vec2( p.x, p.y)) * 1.0;

    COLOR = color / 16.0;
}