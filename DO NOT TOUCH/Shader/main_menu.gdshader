shader_type canvas_item;

// How pixelated?
uniform float pixel_size : hint_range(1.0, 64.0) = 4.0;

// How many color levels?
uniform float color_levels : hint_range(2.0, 64.0) = 16.0;

void fragment()
{
    vec2 tex_size = vec2(textureSize(TEXTURE, 0));

    vec2 uv = floor(UV * tex_size / pixel_size)
            * pixel_size
            / tex_size;

    vec4 color = texture(TEXTURE, uv);

    color.rgb = floor(color.rgb * color_levels) / color_levels;

    COLOR = color;
}