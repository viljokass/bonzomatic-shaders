#version 410 core

uniform float fGlobalTime; // in seconds
uniform vec2 v2Resolution; // viewport resolution (in pixels)
uniform float fFrameTime; // duration of the last frame, in seconds

uniform sampler1D texFFT; // towards 0.0 is bass / lower freq, towards 1.0 is higher / treble freq
uniform sampler1D texFFTSmoothed; // this one has longer falloff and less harsh transients
uniform sampler1D texFFTIntegrated; // this is continually increasing
uniform sampler2D texPreviousFrame; // screenshot of the previous frame
uniform sampler2D texChecker;
uniform sampler2D texNoise;
uniform sampler2D texTex1;
uniform sampler2D texTex2;
uniform sampler2D texTex3;
uniform sampler2D texTex4;

in vec2 out_texcoord;
layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything


const float MAX_D = 100.0;
const float EPSILON = 0.001;
const int MAX_ITER = 100;

float map(vec3 p) {
  return length(p) - (sin(fGlobalTime) + 2) / 4;
}

vec3 raymarch(vec3 ro, vec3 rd) {
  float d = 0.0;
  
  for (int i = 0; i < MAX_ITER; ++i) {
    vec3 p = ro + d * rd;
    float dtc = map(p);
    
    if (dtc < EPSILON) {
      return vec3(1);
    }
    
    if (d > MAX_D) break;
    
    d += dtc;
  }
  return vec3(0);
}

void main(void)
{
  vec2 uv = gl_FragCoord.xy/v2Resolution - vec2(0.5);
  uv.x *= v2Resolution.x/v2Resolution.y;
  vec3 ro = vec3(0, 0, -4);
  vec3 screen = vec3(uv, ro.z + 1);
  vec3 rd = normalize(screen-ro);
  vec3 col = raymarch(ro, rd);
  out_color = vec4(col, 1.0);
}