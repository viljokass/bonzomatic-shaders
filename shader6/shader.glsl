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

const int MAX_ITER = 350;
const float MAX_DIST = 300.0;
const float EPSILON = 0.001;
const float PI = 3.1415;
float fftInt = 0.0;

in vec2 out_texcoord;
layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float sphere(vec3 p, float r) {
  return length(p) - r;
}

vec3 repeat(vec3 p, vec3 s) {
  return mod(p, s) - 0.5f * s;
}

mat2 rotate(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, -s, s, c);
}

float map(vec3 p) {
  
  p.xz *= rotate(sin(fGlobalTime/10)/5);
  p.z += fGlobalTime * 10;
  p.xy *= rotate(sin(fGlobalTime/40));
  p = repeat(p, vec3(10, 10, 5));
  return sphere(p, 1.0 + fftInt * 200);
}

vec3 lpos = vec3(0);

vec3 shade(vec3 p, vec3 n, float d, float i) {
  d /= MAX_DIST/2;
  i /= MAX_ITER/2;
  vec3 dtl = normalize(lpos - p);
  float diffs = dot(dtl, n);
  return vec3(1, 1-d, i) * diffs;
}

vec3 cnorm(vec3 p) {
  vec2 delta = vec2(EPSILON, 0);
  return normalize(vec3(
    map(p + delta.xyy) - map(p - delta.xyy),
    map(p + delta.yxy) - map(p - delta.yxy),
    map(p + delta.yyx) - map(p - delta.yyx)));
}

vec3 raymarch(vec3 ro, vec3 rd) {
  
  float d = 0.0;
  int i = 0;
  
  for (i; i < MAX_ITER; ++i) {
    
    vec3 p = ro + d * rd;
    
    p.y += sin(d/10) * (2 + sin(fGlobalTime/4)/2);
    p.x += cos(d/10) * (2 + sin(fGlobalTime/4)/2);
    
    p.xy *= rotate(d/(MAX_DIST*0.3));

    float dtc = map(p);
    
    if (dtc < EPSILON) {
      vec3 n = cnorm(p);
      return shade(p, n, d, float(i));
    }
    
    if (d > MAX_DIST) break;
    
    d += dtc;
  }
  return vec3(0.1, 0.4, 0.9) * float(i)/(MAX_ITER/2);
}

void main(void)
{
  int amnt = 1024;
  float div = 1/amnt;
  for (int i = 0; i < amnt; ++i) {
    fftInt += texture(texFFTSmoothed, i*div).r;
  }
  fftInt /= amnt;
  vec2 uv = gl_FragCoord.xy/v2Resolution - vec2(0.5);
  uv.x *= v2Resolution.x/v2Resolution.y;
  
  float k = clamp(-0.5, 1 - fftInt * 100, 1);
  
  float res = 256 * k;
  float cold = 8 * k;
  
  uv.x = round(uv.x * res)/res;
  uv.y = round(uv.y * res)/res;
  
  if ( k < 0 ) {
    uv.y *= -1;
    out_color = round(texture(texTex3, uv)*cold)/cold + vec4(vec3(texture(texFFT, abs(uv.x * uv.y)).r * 100, 0, 0), 1);
    return;
  }
  
  vec3 ro = vec3(0, 0, -3);
  vec3 screen = vec3(uv, ro.z + 1);
  vec3 rd = normalize(screen - ro);
  vec4 col = vec4(raymarch(ro, rd), 1);
  
	out_color = round(col * cold)/cold;
}