Shader "Custom/RaymarchingShader"
{
    Properties {
        _Color ("Color", Color) = (1,1,1,1)
        _Loop ("Raymarch Loop", Range(1,300)) = 100
        _MinDistance ("Min Distance", Range(0.0001, 0.1)) = 0.001
        _FractalPower ("Fractal Power", Range(1, 16)) = 8
        _FractalIterations ("Fractal Iterations", Range(1, 20)) = 10
        _Scale ("Scale", Range(0.1, 5.0)) = 1.0
        _ColorIntensity ("Color Intensity", Range(0.1, 5.0)) = 1.0
        _ColorSpeed ("Color Pulse Speed", Range(0.1, 5.0)) = 1.0
        _ColorShift ("Color Shift", Range(0.0, 10.0)) = 1.0
        _FresnelIntensity ("Fresnel Intensity", Range(0.0, 2.0)) = 0.5
        _RotationSpeed ("Rotation Speed", Range(0.0, 2.0)) = 0.2
        _DistortionAmount ("Distortion Amount", Range(0.0, 1.0)) = 0.2
        _DistortionSpeed ("Distortion Speed", Range(0.0, 5.0)) = 1.0
        _PulseAmount ("Pulse Amount", Range(0.0, 1.0)) = 0.2
        _KaleidoscopeAmount ("Kaleidoscope Amount", Range(0.0, 1.0)) = 0.0
        _KaleidoscopeSegments ("Kaleidoscope Segments", Range(1, 20)) = 8
        _GlowIntensity ("Glow Intensity", Range(0.1, 5.0)) = 1.5
        _GlowThreshold ("Glow Threshold", Range(0.0, 1.0)) = 0.5
        _GlowFalloff ("Glow Falloff", Range(0.1, 5.0)) = 2.0
    }
    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Overlay" }
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
            float _ColorIntensity;
            float _ColorSpeed;
            float _ColorShift;
            float _FresnelIntensity;
            float _RotationSpeed;
            float _DistortionAmount;
            float _DistortionSpeed;
            float _PulseAmount;
            float _KaleidoscopeAmount;
            float _KaleidoscopeSegments;
            float _GlowIntensity;
            float _GlowThreshold;
            float _GlowFalloff;
            // _ScreenParams is already defined by Unity

            Varyings vert (Attributes IN) {
                Varyings OUT;
                // Use the URP function to transform object space to clip space.
                OUT.vertex = TransformObjectToHClip(IN.vertex);
                OUT.uv = IN.uv;
                return OUT;
            }

            // Mandelbulb fractal SDF with distortion and pulsing effects
            float sdMandelbulb(float3 pos)
            {
                // Apply time-based pulsing to the scale
                float pulseFactor = 1.0 + sin(_Time.y * _DistortionSpeed) * _PulseAmount;
                pos = pos / (_Scale * pulseFactor); // Scale the space with pulsing effect
                
                // Apply distortion to the position
                float distortTime = _Time.y * _DistortionSpeed;
                float3 distortion = float3(
                    sin(pos.z * 3.0 + distortTime),
                    sin(pos.x * 2.5 + distortTime * 1.1),
                    sin(pos.y * 2.0 + distortTime * 0.9)
                ) * _DistortionAmount;
                
                pos += distortion;
                
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
                
                // Distance estimator with pulsing effect
                return 0.5 * log(r) * r / dr * _Scale * pulseFactor;
            }
            
            // Apply kaleidoscope effect to a position
            float3 applyKaleidoscope(float3 pos)
            {
                if (_KaleidoscopeAmount <= 0.001) return pos; // Skip if effect is disabled
                
                // Apply kaleidoscope in XZ plane
                float angle = atan2(pos.z, pos.x);
                float segment = 6.283185 / _KaleidoscopeSegments; // 2π / segments
                float segmentAngle = floor(angle / segment) * segment;
                float foldAngle = 2.0 * (angle - segmentAngle) - segment;
                
                // Blend between original and kaleidoscope position
                float3 kaleidoPos = pos;
                kaleidoPos.x = cos(foldAngle) * length(pos.xz);
                kaleidoPos.z = sin(foldAngle) * length(pos.xz);
                
                return lerp(pos, kaleidoPos, _KaleidoscopeAmount);
            }
            
            // Combined distance function for the scene
            float distanceFunction(float3 pos)
            {
                // Add time-based animation by rotating the space
                float time = _Time.y * _RotationSpeed;
                float3 rotatedPos = float3(
                    pos.x * cos(time) - pos.z * sin(time),
                    pos.y,
                    pos.x * sin(time) + pos.z * cos(time)
                );
                
                // Apply kaleidoscope effect
                float3 kaleidoPos = applyKaleidoscope(rotatedPos);
                
                return sdMandelbulb(kaleidoPos);
            }

            // A basic raymarching loop.
            float3 raymarch(float3 rayOrigin, float3 rayDir)
            {
                float totalDistance = 0.0;
                for (int i = 0; i < (int)_Loop; i++)
                {
                    float3 pos = rayOrigin + rayDir * totalDistance;
                    float dist = distanceFunction(pos);
                    if (dist < _MinDistance)
                        break;
                    totalDistance += dist;
                    if (totalDistance > 100.0) // Clamp maximum distance.
                        break;
                }
                return rayOrigin + rayDir * totalDistance;
            }

            // Calculate normal at a point using central differences
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
            
            // Generate neon color based on fractal properties with glowing effects
            float4 getNeonFractalColor(float3 pos, float3 normal, float dist)
            {
                // Add time-based pulsation
                float pulseTime = _Time.y * _ColorSpeed;
                
                // Use surface characteristics to determine color
                // - Surface curvature (from normal derivatives)
                // - Distance from origin
                // - Normal direction
                
                // Calculate surface curvature approximation
                float eps = 0.01;
                float3 dx = normalize(calculateNormal(pos + float3(eps, 0, 0)) - normal);
                float3 dy = normalize(calculateNormal(pos + float3(0, eps, 0)) - normal);
                float3 dz = normalize(calculateNormal(pos + float3(0, 0, eps)) - normal);
                float curvature = length(dx + dy + dz) / 3.0;
                
                // Distance from origin affects color hue
                float distFromOrigin = length(pos);
                
                // Use normal direction for color variation
                float normalFactor = (normal.x + normal.y + normal.z) * 0.33 + 0.5;
                
                // Create neon color based on surface characteristics
                float3 baseColor = 0.5 + 0.5 * cos(_ColorIntensity * float3(
                    curvature * 3.0 + pulseTime,
                    distFromOrigin * 0.3 + pulseTime * 0.7,
                    normalFactor * 2.0 + pulseTime * 0.5
                ) + float3(0.1, 0.4, 0.7) + _ColorShift);
                
                // Enhance the neon colors by increasing saturation
                float luminance = dot(baseColor, float3(0.299, 0.587, 0.114));
                baseColor = lerp(float3(luminance, luminance, luminance), baseColor, 1.5);
                
                // Add color variation based on surface curvature
                // High curvature areas get more cyan, flat areas more magenta
                float3 curvatureColor = lerp(
                    float3(1.0, 0.0, 0.8), // Magenta for flat areas
                    float3(0.0, 0.8, 1.0), // Cyan for high curvature
                    saturate(curvature * 2.0)
                );
                
                baseColor = lerp(baseColor, curvatureColor, 0.3);
                
                // Enhanced fresnel effect for edge glow
                float3 viewDir = normalize(pos - _WorldSpaceCameraPos);
                float fresnel = pow(1.0 - abs(dot(normal, viewDir)), 3.0) * _FresnelIntensity * 1.5;
                
                // Calculate glow based on distance from surface
                float glow = smoothstep(_GlowThreshold, _GlowThreshold + _GlowFalloff, fresnel);
                glow = pow(glow, _GlowFalloff) * _GlowIntensity;
                
                // Mix the base color with a neon glow highlight
                // Use colors derived from surface characteristics for the glow
                float3 glowColor = lerp(
                    baseColor * 1.5,
                    float3(1.0, 1.0, 1.0),
                    0.3
                );
                
                float3 finalColor = lerp(baseColor, glowColor, fresnel);
                
                // Add extra emission for the neon effect
                finalColor += glow * glowColor;
                
                // Boost the brightness for a more pronounced glow
                finalColor *= (1.0 + glow * 0.5);
                
                return float4(finalColor, 1.0);
            }
            
            
            float4 frag(Varyings IN) : SV_Target
            {
                // Convert UV from (0,1) to (-1,1) for screen-space direction.
                float2 uv = IN.uv * 2.0 - 1.0;
                
                // Correct for aspect ratio to prevent stretching
                float aspectRatio = _ScreenParams.x / _ScreenParams.y;
                uv.x *= aspectRatio;
                
                // Create the ray in view space
                float3 viewSpaceRay = normalize(float3(uv, 1.0));
                
                // Transform the ray direction from view space to world space using the camera's rotation
                // Extract the rotation part of the camera's view matrix
                float3x3 camToWorldRotation = (float3x3)unity_CameraToWorld;
                float3 rayDir = mul(camToWorldRotation, viewSpaceRay);
                
                float3 rayOrigin = _WorldSpaceCameraPos;
                
                float3 hitPos = raymarch(rayOrigin, rayDir);
                float dist = length(hitPos - rayOrigin);
                
                // If we hit something (within a reasonable distance)
                if (dist < 100.0)
                {
                    // Calculate the normal at the hit point
                    float3 normal = calculateNormal(hitPos);
                    
                    // Create a pulsating light direction for trippy lighting
                    float lightTime = _Time.y * _ColorSpeed * 0.5;
                    float3 lightDir = normalize(float3(
                        sin(lightTime * 0.7),
                        cos(lightTime * 0.5) * 0.5 + 0.5, // Keep light mostly from above
                        sin(lightTime * 0.9)
                    ));
                    
                    float diffuse = max(dot(normal, lightDir), 0.0);
                    float ambient = 0.2; // Reduced ambient to make glow more pronounced
                    
                    // Add color-cycling specular highlight
                    float3 viewDir = normalize(_WorldSpaceCameraPos - hitPos);
                    float3 halfDir = normalize(lightDir + viewDir);
                    float specularStrength = pow(max(dot(normal, halfDir), 0.0), 32.0) * 0.7;
                    
                    // Create rainbow specular with neon colors
                    float3 specularColor = 0.5 + 0.5 * cos(_Time.y * _ColorSpeed + float3(0, 2, 4));
                    float3 specular = specularColor * specularStrength * 1.5; // Enhanced specular
                    
                    // Get the neon fractal color
                    float4 fractalColor = getNeonFractalColor(hitPos, normal, dist);
                    
                    // Apply lighting with color modulation
                    float3 finalColor = fractalColor.rgb * (diffuse + ambient) + specular;
                    
                    // Add some depth fog - darker for space aesthetic
                    float fog = 1.0 - saturate(dist * 0.03);
                    finalColor = lerp(float3(0.0, 0.0, 0.05), finalColor, fog); // Very dark blue fog
                    
                    return float4(finalColor, 1.0);
                }
                else
                {
                    // Pure black background with no stars
                    return float4(0.0, 0.0, 0.0, 1.0);
                }
            }
            ENDHLSL
        }
    }
    FallBack "Universal Forward"
}
