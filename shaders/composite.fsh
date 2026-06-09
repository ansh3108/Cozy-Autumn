#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
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
    if (shadowScreenPos.x < 0.0 || shadowScreenPos.x > 1.0 || shadowScreenPos.y < 0.0 || shadowScreenPos.y > 1.0 || shadowScreenPos.z > 1.0) {
        return vec3(1.0);
    }

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

vec4 getSSR(vec3 viewPos, vec3 viewNormal) {
    vec3 viewDir = normalize(viewPos);
    vec3 reflectDir = normalize(reflect(viewDir, viewNormal));
    
    vec3 currentPos = viewPos;
    vec3 stepDir = reflectDir * max(0.3, length(viewPos) * 0.04);
    
    for (int i = 0; i < 32; i++) {
        currentPos += stepDir;
        vec4 clipPos = gbufferProjection * vec4(currentPos, 1.0);
        vec3 ndcPos = clipPos.xyz / clipPos.w;
        vec3 screenPos = ndcPos * 0.5 + 0.5;
        
        if (screenPos.x < 0.0 || screenPos.x > 1.0 || screenPos.y < 0.0 || screenPos.y > 1.0 || screenPos.z > 1.0) break;
        
        float sceneDepth = texture(depthtex0, screenPos.xy).r;
        vec3 sceneNdc = vec3(screenPos.xy, sceneDepth) * 2.0 - 1.0;
        vec4 sceneClip = gbufferProjectionInverse * vec4(sceneNdc, 1.0);
        vec3 sceneView = sceneClip.xyz / sceneClip.w;
        
        float depthDiff = currentPos.z - sceneView.z;
        if (depthDiff > 0.0 && depthDiff < 1.5) {
            vec2 edgeFade = smoothstep(0.0, 0.1, screenPos.xy) * smoothstep(1.0, 0.9, screenPos.xy);
            float fade = edgeFade.x * edgeFade.y;
            return vec4(texture(colortex0, screenPos.xy).rgb, fade);
        }
    }
    return vec4(0.0);
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
    float isWater = float(texture(colortex2, texcoord).a < 0.2);
    
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

        if (isWater > 0.5) {
            vec3 viewDir = normalize(viewPos);
            vec3 viewNormal = mat3(gbufferModelView) * normal;
            
            float fresnel = pow(1.0 - max(dot(-viewDir, viewNormal), 0.0), 5.0);
            fresnel = mix(0.1, 1.0, fresnel);

            vec4 ssr = getSSR(viewPos, viewNormal);
            
            if (ssr.a > 0.0) {
                ssr.rgb = pow(ssr.rgb, vec3(2.2));
                vec3 amberTint = vec3(1.2, 0.85, 0.4);
                color.rgb = mix(color.rgb, ssr.rgb * amberTint, ssr.a * fresnel * 0.85);
            }
            
            vec3 halfVector = normalize(worldLightVector + normalize(-feetPlayerPos));
            float NdotH = max(dot(normal, halfVector), 0.0);
            float specular = pow(NdotH, 300.0) * 2.5;
            sunlight += sunColor * specular * shadow;
        }

        color.rgb *= (ambient + sunlight + blocklight);
    } else {
        vec3 ndcPos = vec3(texcoord.xy, 1.0) * 2.0 - 1.0;
        vec4 viewClip = gbufferProjectionInverse * vec4(ndcPos, 1.0);
        vec3 viewPos = viewClip.xyz / viewClip.w;
        vec3 worldDir = normalize((gbufferModelViewInverse * vec4(viewPos, 0.0)).xyz);

        float horizonFactor = 1.0 - max(worldDir.y, 0.0);
        horizonFactor = pow(horizonFactor, 4.0);

        vec3 zenithColor = vec3(0.12, 0.20, 0.35);
        vec3 horizonColor = vec3(0.90, 0.40, 0.15);
        vec3 skyColor = mix(zenithColor, horizonColor, horizonFactor);

        float sunGlow = max(dot(worldDir, worldLightVector), 0.0);
        skyColor += vec3(1.0, 0.7, 0.3) * pow(sunGlow, 24.0) * 1.5;
        skyColor += vec3(1.0, 0.9, 0.6) * pow(sunGlow, 128.0) * 4.0;

        color.rgb = skyColor;
    }

    color.rgb *= 1.25; 
    
    vec2 centerDist = texcoord - 0.5;
    float vignette = 1.0 - dot(centerDist, centerDist) * 1.2;
    color.rgb *= smoothstep(0.0, 1.0, vignette);

    color.rgb = ACESFilm(color.rgb);
}


