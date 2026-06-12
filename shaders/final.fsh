#version 330 compatibility

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

in vec2 texcoord;
layout(location = 0) out vec4 color;

#define SHARPENING
#define FILM_GRAIN

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

void main() {
    vec2 texel = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    vec3 finalColor = texture(colortex0, texcoord).rgb;

    #ifdef SHARPENING
        vec3 up    = texture(colortex0, texcoord + vec2(0.0, texel.y)).rgb;
        vec3 down  = texture(colortex0, texcoord + vec2(0.0, -texel.y)).rgb;
        vec3 left  = texture(colortex0, texcoord + vec2(-texel.x, 0.0)).rgb;
        vec3 right = texture(colortex0, texcoord + vec2(texel.x, 0.0)).rgb;
        
        finalColor = finalColor + (finalColor * 4.0 - up - down - left - right) * 0.35;
    #endif

    #ifdef FILM_GRAIN
        float noise = hash(texcoord * 100.0 + frameTimeCounter) * 0.03 - 0.015;
        finalColor += noise;
    #endif

    color = vec4(finalColor, 1.0);
}


