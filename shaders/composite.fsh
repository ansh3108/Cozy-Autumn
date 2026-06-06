#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;

uniform mat4 gbufferModelViewInverse;

const vec3 blocklightColor = vec3(1.0, 0.45, 0.1);
const vec3 skylightColor = vec3(0.15, 0.2, 0.35);
const vec3 ambientColor = vec3(0.15, 0.1, 0.05);
const vec3 sunlightColor = vec3(1.0, 0.75, 0.4);

const vec3 fixedSunPosition = vec3(0.8, 0.3, 0.5);

in vec2 texcoord;

layout(location = 0) out vec4 color;

void main() {
    vec2 lightmap = texture(colortex1, texcoord).xy;
    vec3 encodedNormal = texture(colortex2, texcoord).rgb;
    vec3 normal = normalize((encodedNormal - 0.5) * 2.0);

    vec3 lightVector = normalize(fixedSunPosition);
    vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;

    color = texture(colortex0, texcoord);
    color.rgb = pow(color.rgb, vec3(2.2));

    float depth = texture(depthtex0, texcoord).r;
    if (depth == 1.0) {
        return;
    }

    vec3 blocklight = lightmap.x * blocklightColor;
    vec3 skylight = lightmap.y * skylightColor;
    vec3 ambient = ambientColor;
    vec3 sunlight = sunlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * lightmap.y;

    color.rgb *= blocklight + skylight + ambient + sunlight;

    mat3 autumnTint = mat3(
        1.25, 0.10, 0.00,
        0.15, 0.90, 0.05,
        0.00, 0.05, 0.75
    );
    
    color.rgb = autumnTint * color.rgb;
}

