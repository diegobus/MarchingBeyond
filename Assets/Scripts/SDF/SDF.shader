Shader "Custom/SDFShader"
{
    Properties {
        _MaxSteps ("Max Steps", Range(10, 300)) = 100
        _MaxDistance ("Max Distance", Range(10, 200)) = 100
        _MinDistance ("Min Distance", Range(0.0001, 0.1)) = 0.001
        _FOV ("Field Of View", Range(30, 120)) = 60
        _ShadowIntensity ("Shadow Intensity", Range(0, 1)) = 0.2
        _ShadowSoftness ("Shadow Softness", Range(1, 200)) = 50
        _ShadowBias ("Shadow Bias", Range(0.0001, 0.5)) = 0.01
    }
    SubShader {
        Tags { "RenderType"="Transparent" "Queue"="Overlay" }
        Pass {
            // Enable alpha blending so that when no SDF hit occurs, the underlying skybox (or scene) shows through.
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            ///////////////////////////////
            // Structures and Properties //
            ///////////////////////////////

            struct Attributes {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float _MaxSteps;
            float _MaxDistance;
            float _MinDistance;
            float _FOV;  // Field of view in degrees
            float _ShadowIntensity;
            float _ShadowSoftness;
            float _ShadowBias;

            // Built-in _ScreenParams: x = width, y = height, z = 1 + 1/width, w = 1 + 1/height

            // Camera matrices and position
            float4x4 _CameraToWorld;
            float3 _CameraPosition;
            
            // Light info
            float3 _LightDirection;
            float4 _LightColor;
            
            // Shape definition
            struct ShapeData {
                float3 position;
                float3 scale;
                float4 color;
                float3 rotation; // Euler angles in radians
                int shapeType;
                int operation;
                float blendStrength;
                int numChildren;
                float padding1;
            };
            
            StructuredBuffer<ShapeData> _Shapes;
            int _NumShapes;
            
            ///////////////////
            // Vertex Shader //
            ///////////////////
            
            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.vertex = TransformObjectToHClip(IN.vertex);
                OUT.uv = IN.uv;
                return OUT;
            }
            
            ///////////////////////
            // Ray and Raymarch  //
            ///////////////////////
            
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
                ray.origin = _CameraPosition;
                // Transform the view space direction into world space.
                ray.direction = mul((float3x3)_CameraToWorld, viewDir);
                return ray;
            }
            
            ///////////////////////////////
            // Rotation and Transforms   //
            ///////////////////////////////
            
            // Create a rotation matrix from Euler angles (in radians)
            float3x3 EulerToRotationMatrix(float3 eulerAngles)
            {
                float3 s, c;
                sincos(eulerAngles.x, s.x, c.x); // Roll (x-axis rotation)
                sincos(eulerAngles.y, s.y, c.y); // Pitch (y-axis rotation)
                sincos(eulerAngles.z, s.z, c.z); // Yaw (z-axis rotation)
                
                // Create rotation matrices for each axis
                float3x3 rotX = float3x3(
                    1, 0, 0,
                    0, c.x, -s.x,
                    0, s.x, c.x
                );
                
                float3x3 rotY = float3x3(
                    c.y, 0, s.y,
                    0, 1, 0,
                    -s.y, 0, c.y
                );
                
                float3x3 rotZ = float3x3(
                    c.z, -s.z, 0,
                    s.z, c.z, 0,
                    0, 0, 1
                );
                
                // Combine rotations: Z * Y * X (in that order)
                return mul(mul(rotZ, rotY), rotX);
            }
            
            // Transform a point based on position, rotation, and scale
            float3 TransformPoint(float3 p, float3 position, float3 rotation, float3 scale)
            {
                // Translate point to origin
                float3 q = p - position;
                
                // Apply inverse rotation (transpose of rotation matrix)
                float3x3 rotMatrix = EulerToRotationMatrix(rotation);
                q = mul(transpose(rotMatrix), q);
                
                // Apply inverse scale
                q = q / scale;
                
                return q;
            }
            
            ///////////////////////////////
            // Signed Distance Functions //
            ///////////////////////////////
            
            float SphereDistance(float3 eye, float3 center, float3 scale, float3 rotation)
            {
                float3 p = TransformPoint(eye, center, rotation, scale);
                return (length(p) - 0.5) * min(min(scale.x, scale.y), scale.z);
            }
            
            float BoxDistance(float3 eye, float3 center, float3 scale, float3 rotation)
            {
                float3 p = TransformPoint(eye, center, rotation, scale);
                float3 o = abs(p) - float3(0.5, 0.5, 0.5);
                float ud = length(max(o, 0));
                float n = max(max(min(o.x, 0), min(o.y, 0)), min(o.z, 0));
                return (ud + n) * min(min(scale.x, scale.y), scale.z);
            }
            
            float TorusDistance(float3 eye, float3 center, float3 scale, float3 rotation)
            {
                float3 p = TransformPoint(eye, center, rotation, scale);
                float2 q = float2(length(p.xz) - 0.5, p.y);
                return (length(q) - 0.1) * min(min(scale.x, scale.y), scale.z);
            }
            
            float CylinderDistance(float3 eye, float3 center, float3 scale, float3 rotation)
            {
                float3 p = TransformPoint(eye, center, rotation, scale);
                
                // Cylinder along the Y axis
                float2 d = abs(float2(length(p.xz), p.y)) - float2(0.5, 0.5);
                float outside = length(max(d, 0));
                float inside = min(max(d.x, d.y), 0);
                
                return (outside + inside) * min(min(scale.x, scale.y), scale.z);
            }
            
            float PrismDistance(float3 eye, float3 center, float3 scale, float3 rotation)
            {
                float3 p = TransformPoint(eye, center, rotation, scale);
                
                // Triangular prism along the Y axis
                float3 q = abs(p);
                // Triangular base in the XZ plane
                float d1 = max(q.z - 0.5, max(q.x * 0.866025 + p.z * 0.5, -p.z) - 0.5 * 0.866025);
                // Height along Y axis
                float d2 = q.y - 0.5;
                
                float d = length(max(float2(d1, d2), 0.0)) + min(max(d1, d2), 0.0);
                return d * min(min(scale.x, scale.y), scale.z);
            }
            
            // Get distance for a given shape.
            float GetShapeDistance(ShapeData shape, float3 eye)
            {
                if (shape.shapeType == 0) // Sphere
                {
                    return SphereDistance(eye, shape.position, shape.scale, shape.rotation);
                }
                else if (shape.shapeType == 1) // Cube
                {
                    return BoxDistance(eye, shape.position, shape.scale, shape.rotation);
                }
                else if (shape.shapeType == 2) // Torus
                {
                    return TorusDistance(eye, shape.position, shape.scale, shape.rotation);
                }
                else if (shape.shapeType == 3) // Cylinder
                {
                    return CylinderDistance(eye, shape.position, shape.scale, shape.rotation);
                }
                else if (shape.shapeType == 4) // Prism
                {
                    return PrismDistance(eye, shape.position, shape.scale, shape.rotation);
                }
                return _MaxDistance;
            }
            
            /////////////////////////////////////////////
            // Blending and Combining SDF Primitives   //
            /////////////////////////////////////////////
            
            float4 Blend(float distA, float distB, float4 colorA, float4 colorB, float k)
            {
                float h = clamp(0.5 + 0.5 * (distB - distA) / k, 0.0, 1.0);
                float blendDist = lerp(distB, distA, h) - k * h * (1.0 - h);
                float4 blendColor = lerp(colorB, colorA, h);
                return float4(blendColor.rgb, blendDist);
            }
            
            float4 CombineShapes(float distA, float distB, float4 colorA, float4 colorB, int operation, float blendStrength)
            {
                float resultDist = distA;
                float4 resultColor = colorA;
                
                if (operation == 0) // Union (min)
                {
                    if (distB < distA)
                    {
                        resultDist = distB;
                        resultColor = colorB;
                    }
                }
                else if (operation == 1) // Blend
                {
                    float4 blend = Blend(distA, distB, colorA, colorB, blendStrength);
                    resultDist = blend.w;
                    resultColor = float4(blend.rgb, 1.0);
                }
                else if (operation == 2) // Cut (max(-b, a))
                {
                    // Fixed cut operation based on reference code
                    float cutDist = max(-distB, distA);
                    if (cutDist != distA)
                    {
                        resultDist = cutDist;
                        resultColor = colorB;
                    }
                }
                else if (operation == 3) // Mask (max(a, b))
                {
                    if (distB > distA)
                    {
                        resultDist = distB;
                        resultColor = colorB;
                    }
                }
                return float4(resultColor.rgb, resultDist);
            }
            
            // Evaluate the scene SDF by iterating over all shapes and their children.
            float4 SceneInfo(float3 eye)
            {
                float globalDist = _MaxDistance;
                float4 globalColor = float4(0, 0, 0, 1);
                
                if (_NumShapes <= 0)
                {
                    return float4(0, 0, 0, globalDist);
                }
                
                for (int i = 0; i < _NumShapes; i++)
                {
                    ShapeData shape = _Shapes[i];
                    float localDist = GetShapeDistance(shape, eye);
                    float4 localColor = shape.color;
                    
                    int numChildren = shape.numChildren;
                    int childIndex = i + 1;
                    
                    for (int j = 0; j < numChildren; j++)
                    {
                        if (childIndex < _NumShapes)
                        {
                            ShapeData childShape = _Shapes[childIndex];
                            float childDist = GetShapeDistance(childShape, eye);
                            
                            float4 combined = CombineShapes(
                                localDist, 
                                childDist, 
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
                    i = childIndex - 1;
                    
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
            
            ////////////////////////////////////////
            // Normal Calculation and Lighting    //
            ////////////////////////////////////////
            
            float3 CalculateNormal(float3 pos)
            {
                float eps = _MinDistance;
                float3 normal;
                normal.x = SceneInfo(pos + float3(eps, 0, 0)).w - SceneInfo(pos - float3(eps, 0, 0)).w;
                normal.y = SceneInfo(pos + float3(0, eps, 0)).w - SceneInfo(pos - float3(0, eps, 0)).w;
                normal.z = SceneInfo(pos + float3(0, 0, eps)).w - SceneInfo(pos - float3(0, 0, eps)).w;
                return normalize(normal);
            }
            
            // Calculate shadow intensity using ray marching from hit point to light
            float CalculateShadow(float3 pos, float3 normal)
            {
                // Create shadow ray from the hit point toward the light
                Ray shadowRay;
                shadowRay.origin = pos + normal * _ShadowBias * 2.0; // Offset to prevent self-shadowing
                shadowRay.direction = _LightDirection;
                
                float rayDistance = 0.0;
                int marchSteps = 0;
                float shadow = 1.0; // Start fully lit
                
                // March the ray toward the light
                while (rayDistance < _MaxDistance && marchSteps < _MaxSteps / 2)
                {
                    marchSteps++;
                    float4 sceneInfo = SceneInfo(shadowRay.origin);
                    float dist = sceneInfo.w;
                    
                    // If we hit something, we're in shadow
                    if (dist < _MinDistance)
                    {
                        return _ShadowIntensity; // Hard shadow
                    }
                    
                    // Penumbra calculation - soft shadows
                    // k controls shadow softness (smaller = softer)
                    float k = _ShadowSoftness;
                    shadow = min(shadow, k * dist / rayDistance);
                    
                    // Advance the ray - use a smaller step size for accuracy
                    float stepSize = max(dist * 0.5, _MinDistance);
                    shadowRay.origin += shadowRay.direction * stepSize;
                    rayDistance += stepSize;
                }
                
                // Interpolate between shadow intensity and full brightness
                return lerp(_ShadowIntensity, 1.0, saturate(shadow));
            }
            
            float4 CalculateLighting(float3 pos, float3 normal, float4 albedo)
            {
                float ambient = 0.2;
                
                // Light direction is already set in RaymarchManager.cs
                float3 lightDir = _LightDirection;
                float diffuse = max(dot(normal, lightDir), 0.0);
                
                // Calculate shadow
                float shadow = CalculateShadow(pos, normal);
                
                float3 cameraPos = _CameraPosition;
                float3 viewDir = normalize(cameraPos - pos);
                float3 halfDir = normalize(lightDir + viewDir);
                float specular = pow(max(dot(normal, halfDir), 0.0), 32.0) * 0.5;
                
                // Apply shadow to diffuse and specular components
                float3 lighting = albedo.rgb * ambient + 
                                  albedo.rgb * diffuse * _LightColor.rgb * shadow + 
                                  specular * _LightColor.rgb * shadow;
                
                return float4(lighting, 1.0);
            }
            
            ////////////////////////
            // Raymarch Function  //
            ////////////////////////
            
            float4 Raymarch(Ray ray, float2 uv)
            {
                float distanceTravelled = 0.0;
                bool hit = false;
                float4 hitColor = float4(0, 0, 0, 1);
                float3 hitPosition;
                
                for (int i = 0; i < _MaxSteps; i++)
                {
                    float3 pos = ray.origin + ray.direction * distanceTravelled;
                    float4 sceneInfo = SceneInfo(pos);
                    float dist = sceneInfo.w;
                    
                    if (dist < _MinDistance)
                    {
                        hitPosition = pos;
                        float3 normal = CalculateNormal(pos);
                        float4 albedo = float4(sceneInfo.rgb, 1.0);
                        hitColor = CalculateLighting(pos, normal, albedo);
                        hit = true;
                        break;
                    }
                    
                    distanceTravelled += dist;
                    
                    if (distanceTravelled > _MaxDistance)
                        break;
                }
                
                // If no shape was hit, return a fully transparent color so the underlying skybox is visible.
                if (!hit)
                {
                    return float4(0, 0, 0, 0);
                }
                
                return hitColor;
            }
            
            /////////////////
            // Fragment    //
            /////////////////
            
            float4 frag(Varyings IN) : SV_Target
            {
                Ray ray = CreateRay(IN.uv);
                float4 result = Raymarch(ray, IN.uv);
                return result;
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
