Shader "Custom/FractalShader"
{
    Properties {
        _Loop ("Raymarch Loop", Range(1,300)) = 100
        _MinDistance ("Min Distance", Range(0.0001, 0.1)) = 0.001
        _Scale ("Scale", Range(0.1, 5.0)) = 1.0
        _CSize ("Clamp Size", Range(0.1, 2.0)) = 1.0
        _FOV ("Field Of View", Range(30, 120)) = 60
        
        // Color properties
        _BaseColor ("Base Color", Color) = (0.05, 0.2, 0.15, 1.0)
        
        // Color palette for the quantum realm effect
        _ColorA ("Deep Color", Color) = (0.05, 0.1, 0.3, 1.0)      // Deep blue-purple
        _ColorB ("Mid Color", Color) = (0.2, 0.8, 0.5, 1.0)        // Vibrant teal
        _ColorC ("Bright Color", Color) = (0.9, 0.6, 0.1, 1.0)     // Golden amber
        _ColorD ("Accent Color", Color) = (0.7, 0.05, 0.2, 1.0)    // Deep red
        _ColorVariation ("Color Variation", Range(0.1, 5.0)) = 2.0
        _ColorSpeed ("Color Animation Speed", Range(0.0, 5.0)) = 1.0
        
        // Background colors
        _BackgroundColorA ("Background Color A", Color) = (0.02, 0.05, 0.1, 1)
        _BackgroundColorB ("Background Color B", Color) = (0.05, 0.01, 0.15, 1)
        
        // Fog properties
        _FogColor ("Fog Color", Color) = (0.2, 0.3, 0.4, 1.0)
        _FogDensity ("Fog Density", Range(0.0, 0.1)) = 0.02
        _FogStart ("Fog Start Distance", Range(0.0, 50.0)) = 10.0
        _FogEnd ("Fog End Distance", Range(0.0, 100.0)) = 50.0
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
            float _Scale;
            float _CSize;
            float _FOV;
            
            // Color variables
            float4 _BaseColor;
            float4 _ColorA;
            float4 _ColorB;
            float4 _ColorC;
            float4 _ColorD;
            float _ColorVariation;
            float _ColorSpeed;
            float4 _BackgroundColorA;
            float4 _BackgroundColorB;
            
            // Fog variables
            float4 _FogColor;
            float _FogDensity;
            float _FogStart;
            float _FogEnd;

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

            // Weird global fractal
            // Returns float2 with (iterations, distance)
            float2 sdFractal(float3 p) {
                // Scale the input position
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
                
                // Apply the scale factor
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
            
            // Calculate fog factor based on distance
            float calculateFog(float distance)
            {
                // Linear fog
                float fogFactor = saturate((distance - _FogStart) / (_FogEnd - _FogStart));
                return fogFactor;
            }
            
            // Quantum realm color function - based on palette interpolation
            float3 quantumRealmColor(float3 pos, float3 normal, float3 viewDir, float iterations, float timeValue)
            {
                // Create layered color effect using position, normal and iteration data
                float t1 = sin(dot(pos * 0.1, float3(1.0, 0.5, 0.2)) + timeValue) * 0.5 + 0.5;
                float t2 = cos(dot(normal, float3(0.3, 0.8, 0.4)) * 3.0 + timeValue * 0.7) * 0.5 + 0.5;
                float t3 = sin(iterations * 0.4 + timeValue * 0.5) * 0.5 + 0.5;
                
                // View-dependent effect (like an interference pattern)
                float fresnel = pow(1.0 - saturate(dot(normal, -viewDir)), 4.0);
                
                // Distance from center creates rings
                float distRings = sin(length(pos) * 2.0 - timeValue) * 0.5 + 0.5;
                
                // Combine these parameters for color mixing
                float pattern = (t1 * 0.4 + t2 * 0.3 + t3 * 0.2 + fresnel * 0.5 + distRings * 0.4) / 1.8;
                
                // Modify pattern with iteration data for more depth
                pattern = pattern * (1.0 - iterations / 8.0) + (iterations / 8.0) * sin(pattern * 6.28 + timeValue);
                
                // First color blend
                float3 color1 = lerp(_ColorA.rgb, _ColorB.rgb, saturate(pattern));
                
                // Second color blend
                float3 color2 = lerp(_ColorC.rgb, _ColorD.rgb, saturate(1.0 - pattern));
                
                // Final color blend with iteration influence
                float lerpFactor = sin(iterations * 0.7 + fresnel * 2.0 + timeValue * 0.3) * 0.5 + 0.5;
                return lerp(color1, color2, lerpFactor);
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
                float iterations = marchResult.z;
                bool hit = marchResult.w > 0;
                
                // Time value for animation
                float timeValue = _Time.y * _ColorSpeed;
                
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
                    
                    // Apply quantum realm color effect
                    float3 quantumColor = quantumRealmColor(hitPos, normal, ray.direction, iterations, timeValue);
                    
                    // Blend with base color and lighting
                    float3 finalColor = lerp(_BaseColor.rgb * diffuse, quantumColor, 0.8);
                    
                    // Add subtle pulsing glow based on iteration and time
                    float pulse = sin(iterations * 0.5 + timeValue) * 0.5 + 0.5;
                    finalColor += quantumColor * pulse * 0.3;
                    
                    // Apply variation in intensity
                    finalColor *= (1.0 + sin(dot(hitPos, float3(0.1, 0.2, 0.3)) + timeValue) * 0.2);
                    
                    result = float4(finalColor, 1.0);
                }
                
                // Apply fog based on distance
                float fogFactor = calculateFog(dist);
                result.rgb = lerp(result.rgb, _FogColor.rgb, fogFactor);
                
                return result;
            }
            ENDHLSL
        }
    }
    FallBack "Universal Forward"
}