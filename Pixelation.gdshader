shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
//How pixelated?
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
//How little colors? (Not sure how to describe it)
uniform float color_levels : hint_range(2.0, 64.0) = 16.0;

void fragment()
{
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;

    vec2 uv = floor(SCREEN_UV * resolution / pixel_size)
            * pixel_size
            / resolution;

    vec4 color = texture(screen_texture, uv);

    // Number of brightness levels per channel
    float levels = 16.0;

    color.rgb = floor(color.rgb * color_levels) / color_levels;

    COLOR = color;
}
