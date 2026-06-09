#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform float frameTimeCounter;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 worldPos;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightLevelData;
layout(location = 2) out vec4 encodedNormal;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main() {
    color = texture(gtexture, texcoord) * glcolor;
    
    vec2 wavePos = worldPos.xz * 1.5 + frameTimeCounter * 0.8;
    float wave = noise(wavePos) * 0.5 + noise(wavePos * 2.1 - frameTimeCounter * 1.2) * 0.25;
    
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 bitangent = vec3(0.0, 0.0, 1.0);
    
    vec3 waveNormal = normalize(normal + tangent * wave * 0.15 + bitangent * wave * 0.15);
    
    lightLevelData = vec4(lmcoord, 0.0, 1.0);
    encodedNormal = vec4(waveNormal * 0.5 + 0.5, 0.1); 
}


