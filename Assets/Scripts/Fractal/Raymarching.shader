Shader "Custom/SimpleMandelbulb"
{
    Properties {
        _FractalPower ("Fractal Power", Range(1, 16)) = 8
        _FractalIterations ("Fractal Iterations", Range(1, 20)) = 10
        _Loop ("Raymarch Loop", Range(1,300)) = 100
        _MinDistance ("Min Distance", Range(0.0001, 0.1)) = 0.001
        _Scale ("Scale", Range(0.1, 5.0)) = 1.0
        _CSize ("Clamp Size", Range(0.1, 2.0)) = 1.0
        _FOV ("Field Of View", Range(30, 120)) = 60
        
        // Color properties
        _BaseColor ("Base Color", Color) = (0.2, 0.4, 0.6, 1.0)
        _GlowColor ("Edge Glow Color", Color) = (1.0, 0.5, 0.1, 1.0)
        _GlowIntensity ("Glow Intensity", Range(0, 5)) = 2.0
        _GlowFalloff ("Glow Falloff", Range(1, 10)) = 3.0
        _GlowThreshold ("Glow Threshold", Range(0, 1)) = 0.5
        
        // Background colors
        _BackgroundColorA ("Background Color A", Color) = (0.02, 0.05, 0.1, 1)
        _BackgroundColorB ("Background Color B", Color) = (0.05, 0.01, 0.15, 1)
    }
    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Only include the URP Core library.
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float _Loop;
            float _MinDistance;
            float _FractalPower;
            float _FractalIterations;
            float _Scale;
            float _CSize;
            float _FOV;
            
            // Color variables
            float4 _BaseColor;
            float4 _GlowColor;
            float _GlowIntensity;
            float _GlowFalloff;
            float _GlowThreshold;
            float4 _BackgroundColorA;
            float4 _BackgroundColorB;

            // Ray structure for more organized ray handling
            struct Ray {
                float3 origin;
                float3 direction;
            };

            // Create a ray that accounts for the camera's FOV and aspect ratio.
            Ray CreateRay(float2 uv)
            {
                // Convert UV (0,1) to normalized device coordinates (-1,1)
                float2 ndc = uv * 2.0 - 1.0;

                // Compute the FOV scale. Note that _FOV is in degrees.
                float fovRad = radians(_FOV);
                float fovScale = tan(fovRad * 0.5);

                // Get the aspect ratio from _ScreenParams (x = width, y = height).
                float aspect = _ScreenParams.x / _ScreenParams.y;

                // Adjust the x coordinate by the aspect ratio and scale by the FOV.
                float3 viewDir = normalize(float3(ndc.x * aspect * fovScale, ndc.y * fovScale, 1.0));

                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                // Transform the view space direction into world space.
                ray.direction = mul((float3x3)unity_CameraToWorld, viewDir);
                return ray;
            }

            Varyings vert (Attributes IN) {
                Varyings OUT;
                // Use the URP function to transform object space to clip space.
                OUT.vertex = TransformObjectToHClip(IN.vertex);
                OUT.uv = IN.uv;
                return OUT;
            }

            // Basic Mandelbulb fractal SDF
            // Returns float2 with (iterations, distance)
            float2 sdMandelbulb(float3 pos)
            {
                pos = pos / _Scale; // Scale the space
                
                float3 z = pos;
                float dr = 1.0;
                float r = 0.0;
                float power = _FractalPower;
                int iterations = 0;
                
                for (int i = 0; i < (int)_FractalIterations; i++) {
                    iterations = i;
                    r = length(z);
                    
                    if (r > 2.0) break;
                    
                    // Convert to polar coordinates
                    float theta = acos(z.z / r);
                    float phi = atan2(z.y, z.x);
                    dr = pow(r, power - 1.0) * power * dr + 1.0;
                    
                    // Scale and rotate the point
                    float zr = pow(r, power);
                    theta = theta * power;
                    phi = phi * power;
                    
                    // Convert back to cartesian coordinates
                    z = zr * float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
                    z += pos; // Add the original position back
                }
                
                // Distance estimator
                float dst = 0.5 * log(r) * r / dr * _Scale;
                return float2(iterations, dst);
            }

            // Weird global fractal
            // Returns float2 with (iterations, distance)
            float2 sdFractal(float3 p) {
                // Scale the input position like in sdMandelbulb
                p = p / _Scale;
                
                // Swap coordinates for different orientation
            	p = p.xzy;
                float scale = 1.1;
                
                // Use _CSize as the clamp size parameter
                float3 clampSize = float3(_CSize, _CSize, _CSize);
                int iterations = 0;
                
                for(int i=0; i < 8; i++)
                {
                    iterations = i;
                    p = 2.0 * clamp(p, -clampSize, clampSize) - p;
                    
                    // Use alternate fractal calculation with sine wave
                    float r2 = dot(p, p + sin(p.z * 0.3)); 
                    float k = max(2.0 / r2, 0.5);
                    p *= k;
                    scale *= k;
                }
                
                float l = length(p.xy);
                float rxy = l - 1.0;
                float n = l * p.z;
                rxy = max(rxy, n / 8.0);
                
                // Apply the scale factor like in sdMandelbulb
                float dst = (rxy) / abs(scale) * _Scale;
                return float2(iterations, dst);
            }
            
            // Distance function for the scene
            // Returns float2 with (iterations, distance)
            float2 sceneInfo(float3 pos)
            {
                return sdFractal(pos);
            }

            // A basic raymarching loop
            // Returns float4 with (marchSteps, hitDistance, iterations, hitFlag)
            float4 raymarch(Ray ray)
            {
                float rayDst = 0.0;
                int marchSteps = 0;
                
                for (int i = 0; i < (int)_Loop; i++)
                {
                    marchSteps = i;
                    float3 pos = ray.origin + ray.direction * rayDst;
                    float2 info = sceneInfo(pos);
                    float dist = info.y;
                    
                    if (dist < _MinDistance) {
                        // Hit - return steps, distance, and iterations
                        return float4(marchSteps, rayDst, info.x, 1);
                    }
                    
                    rayDst += dist;
                    if (rayDst > 100.0) // Clamp maximum distance
                        break;
                }
                // No hit - return steps and max distance
                return float4(marchSteps, rayDst, 0, 0);
            }

            // Calculate normal at a point
            float3 calculateNormal(float3 pos)
            {
                const float eps = 0.001;
                float2 e = float2(eps, 0);
                
                float3 normal = normalize(float3(
                    sceneInfo(pos + e.xyy).y - sceneInfo(pos - e.xyy).y,
                    sceneInfo(pos + e.yxy).y - sceneInfo(pos - e.yxy).y,
                    sceneInfo(pos + e.yyx).y - sceneInfo(pos - e.yyx).y
                ));
                
                return normal;
            }
            
            float4 frag(Varyings IN) : SV_Target
            {
                // Background gradient
                float4 result = lerp(_BackgroundColorA, _BackgroundColorB, IN.uv.y);
                
                // Create ray using the CreateRay function
                Ray ray = CreateRay(IN.uv);
                
                // March along the ray
                float4 marchResult = raymarch(ray);
                int marchSteps = marchResult.x;
                float dist = marchResult.y;
                float escapeIterations = marchResult.z;
                bool hit = marchResult.w > 0;
                
                // If we hit something
                if (hit)
                {
                    // Calculate hit position
                    float3 hitPos = ray.origin + ray.direction * dist;
                    
                    // Calculate the normal at the hit point
                    float3 normal = calculateNormal(hitPos);
                    
                    // Basic lighting with a fixed light direction
                    float3 lightDir = normalize(float3(0.5, 0.5, -0.5));
                    float diffuse = max(dot(normal, lightDir), 0.2); // Add some ambient
                    
                    // Apply base color with diffuse lighting
                    float3 baseColorWithLighting = _BaseColor.rgb * diffuse;
                    
                    // Calculate Fresnel/edge glow effect
                    // The dot product of normal and view direction is smallest at grazing angles
                    float fresnel = pow(1.0 - saturate(dot(normal, -ray.direction)), _GlowFalloff);
                    
                    // Apply threshold to control where glow starts
                    fresnel = saturate((fresnel - _GlowThreshold) / (1.0 - _GlowThreshold));
                    
                    // Mix base color with glow color based on fresnel
                    float3 finalColor = lerp(baseColorWithLighting, _GlowColor.rgb, fresnel * _GlowIntensity);
                    
                    // Iteration-based detail can be added to the glow intensity
                    float iterationFactor = saturate(escapeIterations / _FractalIterations);
                    finalColor += _GlowColor.rgb * fresnel * iterationFactor * _GlowIntensity * 0.5;
                    
                    result = float4(finalColor, 1.0);
                }
                
                return result;
            }
            ENDHLSL
        }
    }
    FallBack "Universal Forward"
}
