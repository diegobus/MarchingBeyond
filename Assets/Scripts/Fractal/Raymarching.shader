Shader "Custom/SimpleMandelbulb"
{
    Properties {
        _Color ("Color", Color) = (1,1,1,1)
        _Loop ("Raymarch Loop", Range(1,300)) = 100
        _MinDistance ("Min Distance", Range(0.0001, 0.1)) = 0.001
        _FractalPower ("Fractal Power", Range(1, 16)) = 8
        _FractalIterations ("Fractal Iterations", Range(1, 20)) = 10
        _Scale ("Scale", Range(0.1, 5.0)) = 1.0
        _CSize ("Clamp Size", Range(0.1, 2.0)) = 1.0
        _FOV ("Field Of View", Range(30, 120)) = 60
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

            float4 _Color;
            float _Loop;
            float _MinDistance;
            float _FractalPower;
            float _FractalIterations;
            float _Scale;
            float _CSize;
            float _FOV;

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
            float sdMandelbulb(float3 pos)
            {
                pos = pos / _Scale; // Scale the space
                
                float3 z = pos;
                float dr = 1.0;
                float r = 0.0;
                float power = _FractalPower;
                
                for (int i = 0; i < (int)_FractalIterations; i++) {
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
                return 0.5 * log(r) * r / dr * _Scale;
            }

            // Weird global fractal
            float sdFractal(float3 p) {
                // Scale the input position like in sdMandelbulb
                p = p / _Scale;
                
                // Swap coordinates for different orientation
            	p = p.xzy;
                float scale = 1.1;
                
                // Use _CSize as the clamp size parameter
                float3 clampSize = float3(_CSize, _CSize, _CSize);
                
                for(int i=0; i < 8; i++)
                {
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
                return (rxy) / abs(scale) * _Scale;
            }
            
            // Distance function for the scene
            float distanceFunction(float3 pos)
            {
                return sdFractal(pos);
            }

            // A basic raymarching loop
            float3 raymarch(Ray ray)
            {
                float totalDistance = 0.0;
                for (int i = 0; i < (int)_Loop; i++)
                {
                    float3 pos = ray.origin + ray.direction * totalDistance;
                    float dist = distanceFunction(pos);
                    if (dist < _MinDistance)
                        break;
                    totalDistance += dist;
                    if (totalDistance > 100.0) // Clamp maximum distance
                        break;
                }
                return ray.origin + ray.direction * totalDistance;
            }

            // Calculate normal at a point
            float3 calculateNormal(float3 pos)
            {
                const float eps = 0.001;
                float2 e = float2(eps, 0);
                
                float3 normal = normalize(float3(
                    distanceFunction(pos + e.xyy) - distanceFunction(pos - e.xyy),
                    distanceFunction(pos + e.yxy) - distanceFunction(pos - e.yxy),
                    distanceFunction(pos + e.yyx) - distanceFunction(pos - e.yyx)
                ));
                
                return normal;
            }
            
            float4 frag(Varyings IN) : SV_Target
            {
                // Create ray using the CreateRay function
                Ray ray = CreateRay(IN.uv);
                
                // March along the ray
                float3 hitPos = raymarch(ray);
                float dist = length(hitPos - ray.origin);
                
                // If we hit something (within a reasonable distance)
                if (dist < 100.0)
                {
                    // Calculate the normal at the hit point
                    float3 normal = calculateNormal(hitPos);
                    
                    // Basic lighting with a fixed light direction
                    float3 lightDir = normalize(float3(0.5, 0.5, -0.5));
                    float diffuse = max(dot(normal, lightDir), 0.0);
                    float ambient = 0.2;
                    
                    // Apply base color with simple lighting
                    float3 finalColor = _Color.rgb * (diffuse + ambient);
                    
                    return float4(finalColor, 1.0);
                }
                else
                {
                    // Background color
                    return float4(0.0, 0.0, 0.0, 1.0);
                }
            }
            ENDHLSL
        }
    }
    FallBack "Universal Forward"
}
