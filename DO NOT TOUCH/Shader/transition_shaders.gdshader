shader_type canvas_item;

uniform float progress: hint_range(0.0,1.0);
uniform bool reverse=true;
uniform vec2 numoftile = vec2(16,9);
uniform vec2 pixelprtile = vec2(16,16);

void fragment() {
	vec2 positioninsquare = UV * numoftile;
	vec2 pixelposition = round(positioninsquare * pixelprtile);
	vec2 frac = fract(pixelposition/pixelprtile);
	vec2 direction = abs(frac - 0.5);
	
	
	if(direction.x + direction.y + UV.x + UV.y >= progress * 4.0 ){
		if(!reverse){
			discard;
		}
	}
	else if(reverse){
		discard;
	} 
}
