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

// Yet another raymarching shader lol
// This time from scratch

const float EPSILON = 0.001;
vec3 cp;
vec3 lp;
vec2 uv;

mat2 rotate(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, -s, s, c);  
}

vec3 repeat(vec3 p, vec3 c) {
  return mod(p, c) - 0.5*c;
}

float sdfBox(vec3 p, vec3 d) {
  vec3 q = abs(p) - d;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float ncross(vec3 p, float s) {
  p = repeat(p, vec3(s));
  float sl = s/3;
  float ll = s+0.1;
  float stick0 = sdfBox(p, vec3(ll, sl, sl));
  float stick1 = sdfBox(p, vec3(sl, ll, sl));
  float stick2 = sdfBox(p, vec3(sl, sl, ll));
  return min(min(stick0, stick1), stick2);
}

float pshape(vec3 p) {
  float cube0 = sdfBox(p - vec3(0, 1, 0), vec3(1,2,1));
  float cube1 = sdfBox(p - vec3(1, 0, 1), vec3(1));
  float cube2 = sdfBox(p - vec3(-1, 1.65, 1), vec3(0.7));
  float cube3 = sdfBox(p - vec3(-1.5, 0, 1.5), vec3(0.2, 1, 0.2));
  return min( min(cube0, cube1), min(cube2, cube3));
}

float map(vec3 p) {
  p.y += 1;
  p.xz *= rotate(fGlobalTime/10);
  float pshape = pshape(p);
  float ncross = ncross(p - vec3(0, 0, 0), 0.33);  
  return max(pshape, -ncross);
}

vec3 calcNormal(vec3 p) {
  vec2 epvec = vec2(EPSILON, 0.0);
  return normalize(vec3(map(p + epvec.xyy) - map(p - epvec.xyy), 
                        map(p + epvec.yxy) - map(p - epvec.yxy),
                        map(p + epvec.yyx) - map(p - epvec.yyx)));
}

vec3 lightColor = vec3(1.0f, 1.0f, 0.3f);
float ambientStrength = 0.12;
vec3 ambientColor = lightColor * ambientStrength;
vec3 objectColor = vec3(1.0f, 1.0f, 1.0f);

vec3 calcShading(vec3 p, vec3 n) {
  
  vec3 ambient = ambientStrength * ambientColor;
  
  vec3 dtl = normalize(lp - p);
  vec3 diff = max(dot(n, dtl), 0.0f) * lightColor;
  
  vec3 dtc = normalize(cp - p);
  vec3 ref = normalize(reflect(-dtl, n));
  vec3 spec = pow(max(dot(dtc, ref), 0.0), 32.0) * lightColor;
  
  
  return objectColor * (diff + ambient + spec);
}

vec3 raymarch(vec3 ro, vec3 rd) {
  const float MAXDIST = 250;
  const float MAXSTEPS = 250;
  
  float dist = 0.0f;
  
  for (int i = 0; i < MAXSTEPS; ++i) {
    
    vec3 p = ro + dist * rd;

    float dtc = map(p);
    
    if (dtc < EPSILON) {
      vec3 normal = calcNormal(p);
      return calcShading(p, normal);
    }
    
    if (dist > MAXDIST) break;
    
    dist += dtc;
    
  }
  return ambientColor;
}

void main(void){
  // CAMERA POSITION
  cp = vec3(0.0, 0.0, -8.0);
  // LIGHT POSITION
  lp = cp;
  
  uv = gl_FragCoord.xy/v2Resolution - vec2(0.5f);
  float ar = v2Resolution.x/v2Resolution.y;
  uv.x *= ar;
  float res = 250;
  uv.x = round(uv.x*res)/res;
  uv.y = round(uv.y*res)/res;
  
  
  vec3 screen = vec3(uv, cp.z + 1.0f);
  vec3 rayDir = normalize(screen - cp);
  vec3 marchResult = raymarch(cp, rayDir);
  
  float cdepth = 6;
  
  out_color = vec4(round(marchResult * cdepth)/cdepth, 1.0);
}