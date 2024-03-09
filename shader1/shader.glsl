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

vec3 cameraPosition;
vec3 lightPosition;

const float EPSILON = 0.01f;
const float PI = 3.1415;
const float timeScale = 1.0f;

// A signed distance function for a sphere
float sdfSphere(vec3 p, float r) {
  return length(p) - r;
}

// A signed distance function for a box
float sdfBox(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0f)) + min(max(q.x, max(q.y, q.z)), 0.0f);
}

// Slap all drawables here
float mapTheWorld(vec3 p) {
  float distortionMultiplier = clamp(-0.0f, 1.7f * sin(fGlobalTime * timeScale), 1.7f) * 5.0f;
  float distortion = sin(distortionMultiplier * p.x) * sin(distortionMultiplier * p.y) * sin(distortionMultiplier * p.z) * .15f;
  float sphereRad = 1.0f;
  float sphere0 = sdfSphere(p - vec3(sin(fGlobalTime/7) * 3, 0.0f, 0.0f), sphereRad);
  float cube0 = sdfBox(p - vec3(0.0f), vec3(0.4f, 0.4f, 1.5f));
  return (max(sphere0 + distortion, -cube0));
}

// Calclulate the normal for the object
vec3 calcNormal(vec3 p) {
  const vec2 tinyStep = vec2(EPSILON, 0.0f);
  
  float gradX = mapTheWorld(p + tinyStep.xyy) - mapTheWorld(p - tinyStep.xyy);
  float gradY = mapTheWorld(p + tinyStep.yxy) - mapTheWorld(p - tinyStep.yxy);
  float gradZ = mapTheWorld(p + tinyStep.yyx) - mapTheWorld(p - tinyStep.yyx);
  
  return normalize(vec3(gradX, gradY, gradZ));
}

const float ambientStrength = 0.4f;
const vec3 ambientColor = vec3(1.0f, 0.2f, 1.0f) * ambientStrength;
const vec3 objectColor = vec3(1.0f, 0.6f, 0.6f);

// Calculate shading for the object
vec3 calcShading(vec3 position, vec3 normal) {
  
  vec3 dirToLight = normalize(lightPosition - position);
  float diffuse = max(0.0f, dot(normal, dirToLight));
  
  vec3 dirToCam = normalize(cameraPosition - position);
  vec3 lightReflect = normalize(reflect(-dirToLight, normal));
  float spec = pow(max(dot(dirToCam, lightReflect), 0.0f), 32);
  
  return objectColor * (ambientColor + diffuse + spec);
}

// The raymarch function.
vec3 rayMarch(vec3 ro, vec3 rd) {
  
  float dTraveled = 0.0f;         // Distance travelled so far
  const int STEPNUM = 32;         // Number of maximum steps
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
  // If no hits are registered, return black.
  return ambientColor;
}

// START HERE
void main(void)
{
  // Should be self explanatory
  cameraPosition = vec3(0.0f, 0.0f, -5.0f);
  lightPosition = vec3(1.0f, 1.0f, -3.0f);
  
  // Set up everything for the raymarching and march the ray
  float aspectRatio = v2Resolution.x/v2Resolution.y;    // Aspect ratio of the screen
  vec2 uv = gl_FragCoord.xy/v2Resolution - vec2(0.5f);  // Arrange the screen properly
  uv.x = uv.x * aspectRatio;                            // Apply aspect ratio to the screen x-axis
  vec3 ro = cameraPosition;                             // Ray origin
  vec3 rd = vec3(uv, 1.0f);                             // Ray direction
  vec4 marchResult = vec4(rayMarch(ro, rd), 1);         // Ray march
  
	out_color = marchResult;                              // Output the color
}