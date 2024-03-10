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
// Again, a simple raymarcher, but with shadows this time.
// Exciting stuff

// Function prototypes
vec3 rayMarch(vec3 ro, vec3 rd);

vec3 cameraPosition;
vec3 lightPosition;

const float EPSILON = 0.01f;
const float PI = 3.1415;
const float timeScale = 1.0f/3.0f;

// Some utility functions for logical operations etc.
float unionCSG(float a, float b) {return min(a, b);}
float differenceCSG(float a, float b) {return max(a, -b);}
float intersectionCSG(float a, float b) {return max(a, b);};


// A signed distance function for a sphere
// p - center point
// r - radius
float sdfSphere(vec3 p, float r) {
  return length(p) - r;
}

// A signed distance function for a box
float sdfBox(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0f)) + min(max(q.x, max(q.y, q.z)), 0.0f);
}

// A signed distance function for a hollow sphere
// p - center point
// r - radius
// t - thickness of the sphere
float sdfHollowSphere(vec3 p, float r, float t) {
  float sphere0 = sdfSphere(p, r);
  float sphere1 = sdfSphere(p, r-t);
  return differenceCSG(sphere0, sphere1);
}

// A pacman CSG-SDF
float sdfPacman(vec3 p, float r) {
  float sphere0 = sdfSphere(p, r);
  float cube0 = sdfBox(p - vec3(0.0f, 1.0f, -1.0f), vec3(2.0f, 1.0f, 1.0f));
  float sphere1 = sdfSphere(p - vec3(0, r/2.0f, -r/2.0f), r/5.0f);
  return unionCSG(sphere1, differenceCSG(sphere0, cube0));
}

// A CSG SDF for a ball with a bunch of holes, for testing shadows
float sdfShadowTestObject(vec3 p, float distortionMultip) {
  float distortion = sin(distortionMultip*p.x) * sin(distortionMultip*p.y) * 0.1;
  
  float sphere0 = sdfSphere(p - vec3(0.0f), 1.0f);
  float stick0 = sdfBox(p - vec3(0.0f), vec3(0.4f, 0.4f, 2.0f));
  float stick1 = sdfBox(p - vec3(0.0f), vec3(0.4f, 2.0f, 0.4f));
  float stick2 = sdfBox(p - vec3(0.0f), vec3(2.0f, 0.4f, 0.4f));
  float stickCombo0 = unionCSG(stick0, stick1);
  float stickCombo1 = unionCSG(stick2, stickCombo0);
  float testObject0 = differenceCSG(sphere0, stickCombo1);
  return testObject0 + distortion;
}

// Slap all drawables here
float mapTheWorld(vec3 p) {
  float wall0 = sdfBox(p - vec3(0.0f, 3.0f, 11.0f), vec3(100.0f, 100.0f, 1.0f));
  float limit = 1;
  float testObject0 = sdfShadowTestObject(p - vec3(0.0f, 0.0f, 0.0f), clamp(-limit, sin(fGlobalTime * timeScale), limit) * 25.0f);
  return unionCSG(testObject0, wall0);
}

// Calculate distance from point to a surface
// Almost identical to raymarching function, but this time it returns a length travelled.
// Try to figure out a way to utilize this in the raymarching algorithm
float fromStartToSurface(vec3 ro, vec3 rd) {
  
  float dTraveled = 0.0f;        // Distance travelled so far
  const int STEPNUM = 64;       // Number of maximum steps
  const float MAXDIST = 100.0f;  // Maximum distance for the ray to travel.
  
  for (int i = 0; i < STEPNUM; ++i) {
    
    // Set the current position on the ray
    vec3 currentPosition = ro + dTraveled * rd;
    
    // Calculate the SDFs
    float distanceToClosest = mapTheWorld(currentPosition);
    
    // If a hit, then calculate normals and shading.
    if (distanceToClosest < EPSILON) {
      return dTraveled += distanceToClosest;
    }
    
    // If distance travelled has hit the limit, break the loop
    if (dTraveled > MAXDIST) break;
    
    // Otherwise, add results of the SDF to the travelled distance.
    dTraveled += distanceToClosest;
  }
  // If no hits are registered, return ambient color.
  return 1.0 / 0.0;
}

// Variables for lighting, light colours and such
const float ambientStrength = 0.4f;
const vec3 ambientColor = vec3(1.0f, 1.0f, 1.0f);
const vec3 lightColor = vec3(1.0f, 1.0f,  0.0f);
const vec3 objectColor = vec3(1.0f, 0.0f, 1.0f);

// Calculate shading for the object
vec3 calcShading(vec3 position, vec3 normal) {
  
  vec3 ambientLight = ambientColor * ambientStrength;
  
  // Calculate shadows
  if (fromStartToSurface(lightPosition, normalize(position - lightPosition)) + 15 * EPSILON < length(position - lightPosition))
    return objectColor * ambientLight;
  
  vec3 dirToLight = normalize(lightPosition - position);
  vec3 diffuseLight = max(0.0f, dot(normal, dirToLight)) * lightColor;
  
  vec3 dirToCam = normalize(cameraPosition - position);
  vec3 lightReflect = normalize(reflect(-dirToLight, normal));
  vec3 specLight = pow(max(dot(dirToCam, lightReflect), 0.0f), 32) * lightColor;
  
  return objectColor * (ambientLight + diffuseLight + specLight);
}

// Calclulate the normal for the object
vec3 calcNormal(vec3 p) {
  const vec2 tinyStep = vec2(EPSILON, 0.0f);
  
  float gradX = mapTheWorld(p + tinyStep.xyy) - mapTheWorld(p - tinyStep.xyy);
  float gradY = mapTheWorld(p + tinyStep.yxy) - mapTheWorld(p - tinyStep.yxy);
  float gradZ = mapTheWorld(p + tinyStep.yyx) - mapTheWorld(p - tinyStep.yyx);
  
  return normalize(vec3(gradX, gradY, gradZ));
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
  cameraPosition = vec3(0.0f, 0.0f, -10.0f);
  lightPosition = vec3(0.0f, 0.0f, sin(fGlobalTime * timeScale/2));
  
  // Set up everything for the raymarching and march the ray
  float aspectRatio = v2Resolution.x/v2Resolution.y;
  vec2 uv = gl_FragCoord.xy/v2Resolution - vec2(0.5f);
  uv.x = uv.x * aspectRatio;
  vec3 ro = cameraPosition;
  vec3 screen = vec3(uv, ro.z + 1.0f);
  vec3 rd = normalize(screen - ro);
  vec4 marchResult = vec4(rayMarch(ro, rd), 1);
  
	out_color = marchResult;                              // Output the color
}