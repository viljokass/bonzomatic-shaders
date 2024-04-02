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

struct Surface {
  float sdv;
  vec3 col;
};

mat2 rotate(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, -s, s, c);
}

Surface sphere(vec3 p, float r, vec3 offset, vec3 col) {
  float d = length(p - offset) - r;
  return Surface(d, col);
}

Surface minWithColor(Surface o1, Surface o2) {
  if (o2.sdv < o1.sdv) return o2;
  return o1;
}

Surface map(vec3 p) {
  p.xy *= rotate(fGlobalTime);
  Surface s1 = sphere(p, 1., vec3(-1.5, -0.7, 0), vec3(1, 0, 0));
  Surface s2 = sphere(p, 1., vec3(1.5, -0.7, 0), vec3(0, 1, 0));
  Surface s3 = sphere(p, 1., vec3(0, 1.8, 0), vec3(0, 0, 1));
  return minWithColor(minWithColor(s1, s2), s3);
}

vec3 cnorm(vec3 p) {
  vec2 delta = vec2(EPSILON, 0);
  return normalize(vec3(
    map(p + delta.xyy).sdv - map(p - delta.xyy).sdv,
    map(p + delta.yxy).sdv - map(p - delta.yxy).sdv,
    map(p + delta.yyx).sdv - map(p - delta.yyx).sdv
  ));
}

vec3 lpos = vec3(0, 0, sin(fGlobalTime)*2);

vec3 shade(vec3 p, vec3 n, vec3 col) {
  vec3 dtl = normalize(lpos - p);
  float diffs = max(dot(dtl, n), 0.0);
  return col * diffs;
}

vec3 raymarch(vec3 ro, vec3 rd) {
  float d = 0.0;
  
  for (int i = 0; i < MAX_ITER; ++i) {
    vec3 p = ro + d * rd;
    Surface obj = map(p);
    float dtc = obj.sdv;
    
    if (dtc < EPSILON) {
      vec3 n = cnorm(p);
      return shade(p, n, obj.col);
    }
    
    if (d > MAX_D) break;
    
    d += dtc;
  }
  return vec3(0);
}

void main(void)
{
  vec2 uv = gl_FragCoord.xy/v2Resolution * 2 - vec2(1);
  uv.x *= v2Resolution.x/v2Resolution.y;
  vec3 ro = vec3(0, 0, -4);
  vec3 screen = vec3(uv, ro.z + 1);
  vec3 rd = normalize(screen-ro);
  vec3 col = raymarch(ro, rd);
  out_color = vec4(col, 1.0);
}