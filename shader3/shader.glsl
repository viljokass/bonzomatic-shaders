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

// A Bonzomatic shader made by viljokass.
// Another raymarher. This time, transformations and domain expansions have been tried.

vec3 cameraPosition;
vec3 lightPosition;

const float EPSILON = 0.001f;
const float PI = 3.1415;
const float timeScale = 1.0f;

// Some utility functions for logical operations etc.
float unionCSG(float a, float b) {return min(a, b);}
float differenceCSG(float a, float b) {return max(a, -b);}
float intersectionCSG(float a, float b) {return max(a, b);};

// A signed distance function for a sphere
float sdfSphere(vec3 p, float r) {
  return length(p) - r;
}

// A signed distance function for a box
float sdfBox(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0f)) + min(max(q.x, max(q.y, q.z)), 0.0f);
}

vec3 repeat(vec3 p, vec3 c) {
   return mod(p, c) - 0.5f * c;
}

mat2 rotate(float angle) {
  float s = sin(angle);
  float c = cos(angle);
  return mat2(c, -s, s, c);
}

// Slap all drawables here
float mapTheWorld(vec3 p) {
  p.xz *= rotate(sin(fGlobalTime)/10);
  p -= vec3(sin(fGlobalTime)*0.2, cos(fGlobalTime)*0.1f, -fGlobalTime * 8.5f);
  p.xy *= rotate(PI/4.0f);
  p = repeat(p, vec3(5.0f, 5.0f, 5.0f));
  float sphere0 = sdfSphere(p - vec3(0.0f, 0.0f, 0.0f), 1.0f);
  float cube0 = sdfBox(p - vec3(1.0f, 1.0f, 0.0f), vec3(1.0f, 1.0f, 2.0f));
  float sphere1 = sdfSphere(p - vec3(0.5f, 0.5f, 0.0f), 0.2f);
  return unionCSG(sphere1, differenceCSG(sphere0, cube0));
}

// Calclulate the normal for the object
vec3 calcNormal(vec3 p) {
  const vec2 tinyStep = vec2(EPSILON, 0.0f);
  
  float gradX = mapTheWorld(p + tinyStep.xyy) - mapTheWorld(p - tinyStep.xyy);
  float gradY = mapTheWorld(p + tinyStep.yxy) - mapTheWorld(p - tinyStep.yxy);
  float gradZ = mapTheWorld(p + tinyStep.yyx) - mapTheWorld(p - tinyStep.yyx);
  
  return normalize(vec3(gradX, gradY, gradZ));
}

// Variables for lighting, light colours and such
const float ambientStrength = 0.3f;
const vec3 ambientColor = vec3(0.0f, 0.0f, 0.0f);
const vec3 lightColor = vec3(1.0f, 1.0f,  1.0f);
const vec3 objectColor = vec3(0.2196f, 0.4901f, 1.0f);

// Calculate shading for the object
vec3 calcShading(vec3 position, vec3 normal) {
  
  vec3 ambientLight = ambientColor * ambientStrength;
  
  vec3 dirToLight = normalize(lightPosition - position);
  vec3 diffuseLight = max(0.0f, dot(normal, dirToLight)) * lightColor;
  
  return objectColor * (ambientLight + diffuseLight);
}

// The raymarch function.
vec3 rayMarch(vec3 ro, vec3 rd) {
  
  float dTraveled = 0.0f;         // Distance travelled so far
  const int STEPNUM = 100;         // Number of maximum steps
  const float MAXDIST = 100.0f;  // Maximum distance for the ray to travel.
  
  for (int i = 0; i < STEPNUM; ++i) {
    
    // Set the current position on the ray
    vec3 currentPosition = ro + dTraveled * rd;
    
    // Calculate the SDFs
    float distanceToClosest = mapTheWorld(currentPosition);
    
    // If a hit, then calculate normals and shading.
    if (distanceToClosest < EPSILON) {
      vec3 normal = calcNormal(currentPosition);
      return calcShading(currentPosition, normal);
    }
    
    // If distance travelled has hit the limit, break the loop
    if (dTraveled > MAXDIST) break;
    
    // Otherwise, add results of the SDF to the travelled distance.
    dTraveled += distanceToClosest;
  }
  // If no hits are registered, return ambient color.
  
  return ambientColor * ambientStrength;
}

// START HERE
void main(void)
{
  // Should be self explanatory
  cameraPosition = vec3(0.0f, 0.0f, -5.0f);
  lightPosition = cameraPosition;
  
  // Set up everything for the raymarching and march the ray
  float aspectRatio = v2Resolution.x/v2Resolution.y;
  vec2 uv = gl_FragCoord.xy/v2Resolution - vec2(0.5f);
  uv.x = uv.x * aspectRatio;
  vec3 ro = cameraPosition;
  vec3 screen = vec3(uv, ro.z + 1.0f);
  vec3 rd = normalize(screen - ro);
  vec4 marchResult = vec4(rayMarch(ro, rd), 1.0f);
  
  float s = sin(fGlobalTime);
  
  float intensity = texture(texFFT, abs(uv.y*uv.x*6) * 0.3).r * 250 * (s+1.5);
  vec2 sc = gl_FragCoord.xy/v2Resolution;
  vec4 paerinaevaeri = vec4(sc.x, sc.y, 0.0f, 1.0f) * intensity;
  
  if (s > 0)
    if (marchResult.b > 0.0f) paerinaevaeri = vec4(0.0f);
  
	out_color = marchResult + paerinaevaeri;                              // Output the color
}