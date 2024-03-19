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
float fftIntegrate;

float sdfSphere(vec3 p, float r) {
  return length(p) - r;
}

float smin(float a, float b, float k ) {
    k *= log(2.0);
    float x = b-a;
    return a + x/(1.0-exp2(x/k));
}

float map(vec3 p) {
  vec3 s0loc = vec3( sin(fGlobalTime/2.2) * 3, 0.0, 0.0);
  vec3 s1loc = vec3( 0.0, sin(fGlobalTime/1.43) * 2,  0.0);
  vec3 s2loc = vec3( 0.0, cos(fGlobalTime/3.2) * 2.4,  0.0);
  
  float sphere0 = sdfSphere(p - s0loc, 0.3);
  float sphere1 = sdfSphere(p - s1loc, 0.3);
  float sphere2 = sdfSphere(p - s2loc, 0.3);
  
  float fftwc = fftIntegrate * 1500;
  
  float disturbance = sin(p.x * fftwc) * sin(p.y * fftwc) * sin(p.z * fftwc) * 0.18;
  
  return smin(smin(sphere0, sphere1, 0.8), sphere2, 0.8) + disturbance;
}

vec3 calcNormal(vec3 p) {
  vec2 epvec = vec2(EPSILON, 0.0);
  return normalize(vec3(map(p + epvec.xyy) - map(p - epvec.xyy), 
                        map(p + epvec.yxy) - map(p - epvec.yxy),
                        map(p + epvec.yyx) - map(p - epvec.yyx)));
}

float ambientStrength = 0.12;
vec3 ambientColor = vec3(1.0, 1.0, 1.0);
vec3 lightColor = vec3(0.5f, 0.7f, 1.0f);
vec3 objectColor = vec3(0.3f, 0.3f, 0.8f);

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
  const float MAXSTEPS = 64;
  
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
  float intens = texture(texFFTSmoothed, abs(uv.x * uv.y)).r * 100;
  return vec3(intens, intens*0.5, 1) * ambientStrength;
}

void main(void){
  
  float integrateStep = 1/1024;
  float integrateCount = 32;
  for (int i = 0; i < integrateCount; ++i) {
    fftIntegrate += texture(texFFTSmoothed, i * integrateStep).r;
  }
  fftIntegrate /= integrateCount;
  
  // CAMERA POSITION
  cp = vec3(0.0, 0.0, -8.0);
  // LIGHT POSITION
  lp = vec3(3.0f, 2.0f, -3.0f);
  
  uv = gl_FragCoord.xy/v2Resolution - vec2(0.5f);
  float ar = v2Resolution.x/v2Resolution.y;
  uv.x *= ar;
  vec3 screen = vec3(uv, cp.z + 1.0f);
  vec3 rayDir = normalize(screen - cp);
  vec3 marchResult = raymarch(cp, rayDir);
  
  out_color = vec4(marchResult, 1.0);
}