Shader "Custom/SDFShader"
{
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
        _MaxSteps ("Max Steps", Range(10, 300)) = 100
        _MaxDistance ("Max Distance", Range(10, 200)) = 100
        _MinDistance ("Min Distance", Range(0.0001, 0.1)) = 0.001
    }
    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Overlay" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float _MaxSteps;
            float _MaxDistance;
            float _MinDistance;
            
            // Camera matrices
            float4x4 _CameraToWorld;
            float4x4 _CameraInverseProjection;
            float3 _CameraPosition;
            
            // Light info
            float3 _LightDirection;
            float4 _LightColor;
            
            // Shape definition
            struct ShapeData {
                float3 position;
                float3 scale;
                float4 color;
                int shapeType;
                int operation;
                float blendStrength;
                int numChildren;
                float padding1;
                float padding2;
                float padding3;
            };
            
            StructuredBuffer<ShapeData> _Shapes;
            int _NumShapes;

            Varyings vert (Attributes IN) {
                Varyings OUT;
                OUT.vertex = TransformObjectToHClip(IN.vertex);
                OUT.uv = IN.uv;
                return OUT;
            }
            
            struct Ray {
                float3 origin;
                float3 direction;
            };
            
            Ray CreateRay(float2 uv) {
                Ray ray;
                float2 normalizedUV = uv * 2.0 - 1.0;
                float3 viewSpaceDir = float3(normalizedUV, 1.0);
                ray.origin = _CameraPosition;
                ray.direction = mul((float3x3)_CameraToWorld, normalize(viewSpaceDir));
                return ray;
            }
            
            // SDF primitives
            float SphereDistance(float3 eye, float3 center, float3 scale) {
                return (length((eye - center) / scale) - 0.5) * min(min(scale.x, scale.y), scale.z);
            }
            
            float BoxDistance(float3 eye, float3 center, float3 scale) {
                float3 o = abs((eye - center) / scale) - float3(0.5, 0.5, 0.5);
                float ud = length(max(o, 0));
                float n = max(max(min(o.x, 0), min(o.y, 0)), min(o.z, 0));
                return (ud + n) * min(min(scale.x, scale.y), scale.z);
            }
            
            float TorusDistance(float3 eye, float3 center, float3 scale) {
                float3 p = (eye - center) / scale;
                float2 q = float2(length(p.xz) - 0.5, p.y);
                return (length(q) - 0.1) * min(min(scale.x, scale.y), scale.z);
            }
            
            // Get distance for a specific shape
            float GetShapeDistance(ShapeData shape, float3 eye) {
                if (shape.shapeType == 0) { // Sphere
                    return SphereDistance(eye, shape.position, shape.scale);
                }
                else if (shape.shapeType == 1) { // Cube
                    return BoxDistance(eye, shape.position, shape.scale);
                }
                else if (shape.shapeType == 2) { // Torus
                    return TorusDistance(eye, shape.position, shape.scale);
                }
                
                return _MaxDistance;
            }
            
            // Blend function
            float4 Blend(float distA, float distB, float4 colorA, float4 colorB, float k) {
                float h = clamp(0.5 + 0.5 * (distB - distA) / k, 0.0, 1.0);
                float blendDist = lerp(distB, distA, h) - k * h * (1.0 - h);
                float4 blendColor = lerp(colorB, colorA, h);
                return float4(blendColor.rgb, blendDist);
            }
            
            // Combine two shapes based on operation
            float4 CombineShapes(float distA, float distB, float4 colorA, float4 colorB, int operation, float blendStrength) {
                float resultDist = distA;
                float4 resultColor = colorA;
                
                if (operation == 0) { // Union (min)
                    if (distB < distA) {
                        resultDist = distB;
                        resultColor = colorB;
                    }
                }
                else if (operation == 1) { // Blend
                    float4 blend = Blend(distA, distB, colorA, colorB, blendStrength * 1.0);
                    resultDist = blend.w;
                    resultColor = float4(blend.rgb, 1.0);
                }
                else if (operation == 2) { // Cut (max(-b,a))
                    if (-distB > distA) {
                        resultDist = -distB;
                        resultColor = colorB;
                    }
                }
                else if (operation == 3) { // Mask (max(a,b))
                    if (distB > distA) {
                        resultDist = distB;
                        resultColor = colorB;
                    }
                }
                
                return float4(resultColor.rgb, resultDist);
            }
            
            // Get distance and color for the entire scene
            float4 SceneInfo(float3 eye) {
                float globalDist = _MaxDistance;
                float4 globalColor = float4(0, 0, 0, 1);
                
                // No objects case
                if (_NumShapes <= 0) {
                    return float4(0, 0, 0, globalDist);
                }
                
                // Process all shapes
                for (int i = 0; i < _NumShapes; i++) {
                    ShapeData shape = _Shapes[i];
                    
                    float localDist = GetShapeDistance(shape, eye);
                    float4 localColor = shape.color;
                    
                    // Process children 
                    int numChildren = shape.numChildren;
                    int childIndex = i + 1;
                    
                    for (int j = 0; j < numChildren; j++) {
                        if (childIndex < _NumShapes) {
                            ShapeData childShape = _Shapes[childIndex];
                            float childDst = GetShapeDistance(childShape, eye);
                            
                            float4 combined = CombineShapes(
                                localDist, 
                                childDst, 
                                localColor, 
                                childShape.color, 
                                childShape.operation, 
                                childShape.blendStrength
                            );
                            
                            localColor = float4(combined.rgb, 1.0);
                            localDist = combined.w;
                            
                            childIndex++;
                        }
                    }
                    
                    // Skip processed children
                    i = childIndex - 1;
                    
                    // Combine with global scene
                    float4 combined = CombineShapes(
                        globalDist, 
                        localDist, 
                        globalColor, 
                        localColor, 
                        shape.operation, 
                        shape.blendStrength
                    );
                    
                    globalDist = combined.w;
                    globalColor = float4(combined.rgb, 1.0);
                }
                
                return float4(globalColor.rgb, globalDist);
            }
            
            // Calculate normal at a point using central differences
            float3 CalculateNormal(float3 pos) {
                const float eps = _MinDistance;
                float2 e = float2(eps, 0);
                
                float3 normal = normalize(float3(
                    SceneInfo(pos + e.xyy).w - SceneInfo(pos - e.xyy).w,
                    SceneInfo(pos + e.yxy).w - SceneInfo(pos - e.yxy).w,
                    SceneInfo(pos + e.yyx).w - SceneInfo(pos - e.yyx).w
                ));
                
                return normal;
            }
            
            // Simple lighting calculation
            float4 CalculateLighting(float3 pos, float3 normal, float4 albedo) {
                // Simple ambient, diffuse, specular calculation
                float ambient = 0.2;
                float diffuse = max(dot(normal, -_LightDirection), 0.0);
                
                // Add specular highlight
                float3 viewDir = normalize(_CameraPosition - pos);
                float3 halfDir = normalize(-_LightDirection + viewDir);
                float specular = pow(max(dot(normal, halfDir), 0.0), 32.0) * 0.5;
                
                // Calculate shadow
                // (simplified - no actual shadow raymarching)
                float shadow = 1.0;
                
                // Combine lighting
                float3 lighting = albedo.rgb * (ambient + diffuse * _LightColor.rgb * shadow) + specular * _LightColor.rgb;
                
                return float4(lighting, 1.0);
            }
            
            // Raymarch through the scene
            float4 Raymarch(Ray ray) {
                float distance = 0.0;
                
                for (int i = 0; i < _MaxSteps; i++) {
                    float3 pos = ray.origin + ray.direction * distance;
                    float4 sceneInfo = SceneInfo(pos);
                    float dist = sceneInfo.w;
                    
                    if (dist < _MinDistance) {
                        // Hit something
                        float3 normal = CalculateNormal(pos);
                        float4 albedo = float4(sceneInfo.rgb, 1.0);
                        
                        // Apply lighting
                        return CalculateLighting(pos, normal, albedo);
                    }
                    
                    distance += dist;
                    
                    if (distance > _MaxDistance) {
                        break;
                    }
                }
                
                // Nothing hit - return background
                return float4(0, 0, 0, 1);
            }
            
            float4 frag(Varyings IN) : SV_Target {
                // Create the ray
                Ray ray = CreateRay(IN.uv);
                
                // Raymarch
                float4 result = Raymarch(ray);
                
                return result;
            }
            ENDHLSL
        }
    }
}