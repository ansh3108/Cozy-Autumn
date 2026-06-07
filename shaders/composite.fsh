#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

const vec3 sunColor = vec3(1.4, 0.85, 0.4); 
const vec3 skyAmbient = vec3(0.15, 0.25, 0.45); 
const vec3 groundAmbient = vec3(0.15, 0.08, 0.03); 
const vec3 blocklightColor = vec3(1.2, 0.6, 0.15); 

const vec3 lockedSunVector = normalize(vec3(0.8, 0.2, 0.5));

in vec2 texcoord;

layout(location = 0) out vec4 color;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / homPos.w;
}

vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float distortionFactor = length(shadowClipPos.xy);
    distortionFactor += 0.1;
    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5;
    return shadowClipPos;
}

vec3 getSoftShadow(vec3 shadowScreenPos) {
    vec3 shadowAcc = vec3(0.0);
    float texel = 1.0 / 2048.0; 
    
    vec2 offsets[5] = vec2[5](
        vec2(0.0, 0.0),
        vec2(1.5, 1.5) * texel,
        vec2(-1.5, -1.5) * texel,
        vec2(1.5, -1.5) * texel,
        vec2(-1.5, 1.5) * texel
    );

    for(int i = 0; i < 5; i++) {
        vec2 samplePos = shadowScreenPos.xy + offsets[i];
        float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, samplePos).r);
        
        if (transparentShadow == 1.0) {
            shadowAcc += vec3(1.0);
        } else {
            float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, samplePos).r);
            if (opaqueShadow == 0.0) {
                shadowAcc += vec3(0.1, 0.15, 0.25) * 0.3; 
            } else {
                vec4 sColor = texture(shadowcolor0, samplePos);
                shadowAcc += sColor.rgb * (1.0 - sColor.a);
            }
        }
    }
    return shadowAcc / 5.0;
}
vec3 ACESFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec2 lightmap = texture(colortex1, texcoord).xy;
    vec3 encodedNormal = texture(colortex2, texcoord).rgb;
    vec3 normal = normalize((encodedNormal - 0.5) * 2.0);
    
    vec3 worldLightVector = mat3(gbufferModelViewInverse) * lockedSunVector;

    color = texture(colortex0, texcoord);
    
    color.rgb = pow(color.rgb, vec3(2.2)); 

    float depth = texture(depthtex0, texcoord).r;
    
    if (depth < 1.0) {
        vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
        vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
        vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        
        vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
        vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
        shadowClipPos.z -= 0.001;  
        shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz);
        
        vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
        vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;

        vec3 shadow = getSoftShadow(shadowScreenPos);

        float upFactor = normal.y * 0.5 + 0.5;
        vec3 ambient = mix(groundAmbient, skyAmbient, upFactor) * lightmap.y;

        float NdotL = max(dot(normal, worldLightVector), 0.0);
        vec3 sunlight = sunColor * NdotL * shadow * lightmap.y;
        vec3 blocklight = blocklightColor * lightmap.x;
        
        color.rgb *= (ambient + sunlight + blocklight);
    }

    color.rgb *= 1.25; 
    
    vec2 centerDist = texcoord - 0.5;
    float vignette = 1.0 - dot(centerDist, centerDist) * 1.2;
    color.rgb *= smoothstep(0.0, 1.0, vignette);

    color.rgb = ACESFilm(color.rgb);
}
