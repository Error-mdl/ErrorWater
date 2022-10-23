/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/* DEPTH FUNCTIONS                                                           */
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/

#include "Packages/com.error.birptourp/ShaderLibrary/DeclareDepthTexture.hlsl"

/** @brief Returns the distance between a given point and the worldspace position calculated from the depth
 *         read from the depth texture at the given screen UVs.
 * 
 *  If the front face is being rendered, for a given worldspace position offsetPos with screen coordinates
 *  uvDepth, this calculates the worldspace position of the value in the depth texture measured at uvDepth.
 *  Then it calculates the distance between this position and another worldspace position wPos. Then, for
 *  a given normal, this calculates if the depth position is above or below the plane defined by wPos and
 *  the normal and negates the calculated distance between the two points if its above. It then returns the
 *  distance. If the back face is being rendered, simply return the distance from wPos to the camera
 *
 *  @param wPos         Worldspace position on the surface of the water to measure the distance from
 *  @param offsetPos    Worldspace position of the refracted ray to read the depth from the depth texture at
 *  @param normal       Normal direction to use to determine if the position measured from depth is above
 *                      or below the water. Its best to use mesh normals ones unmodified by normal maps
 *  @param uvDepth      Screen UV's corresponding to offsetPos at which the depth texture will be sampled
 *  @param facing       SV_IsFrontFace, > 0 if the face is a front face, <= 0 otherwise
 *
 *  @return If facing > 0, the distance from wPos to the point calculated from the depth texture at uvDepth,
 *          with sign positive if it is below the surface of the water or negative if it is above. If facing
 *          < 0, the distance to wPos from the camera.
 */
float getDepthDifference(float3 wPos, float3 offsetPos, float3 normal, float2 uvDepth, float facing)
{
    float depthDifference;
    UNITY_BRANCH if (facing > 0)
    {
        float rawDepth = SAMPLE_TEXTURE2D_X_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, uvDepth, 0);
        float farDepth = Linear01Depth(rawDepth);
        float3 wRay = offsetPos - _WorldSpaceCameraPos;
        float wRayDepth = dot(wRay, -UNITY_MATRIX_I_V._m02_m12_m22);
        float3 depthPos = wRay * (_ProjectionParams.z / wRayDepth) * farDepth + _WorldSpaceCameraPos;
        float3 depthRay = depthPos - wPos;
        float depthSign = -dot(normal, depthRay);
        depthDifference = (sign(depthSign)) * length(depthRay);
    }
    else
    {
        //float3 camPos = mul((float3x4)UNITY_MATRIX_V, wPos);
        depthDifference = length(wPos.xyz - _WorldSpaceCameraPos);
    }
    return depthDifference;
}

/** @brief Calculates a thickness fade factor based on the depth texture used to fade the water out around the edges
 *
 * @param wPos      Worldspace position of the pixel
 * @param normal    Mesh normal at the pixel
 * @param facing    SV_IsFrontFace, > 0 if the face is a front face, <= 0 otherwise
 *
 * @return A value ranging from 0 and 1 as distance between wPos and the depth measured at wpos in the depth texture ranges from 0 to _DepthFade 
 */

float getDepthFade(float4 wPos, float3 normal, float facing)
{
#ifdef SOFTPARTICLES_ON
    float4 spos = ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, wPos));
    float2 uvDepth = spos.xy / spos.w;
    float depthDifference = getDepthDifference(wPos.xyz, wPos.xyz, normal, uvDepth, facing);
    float depthFactor = smoothstep(0, _DepthFade, depthDifference);
    depthFactor = depthFactor;
    return depthFactor;
#else
    return 1;
#endif
}


/** @brief Refracts a ray from the camera to the given world position by a given normal, and returns the world
 *          position of a point a fixed distance along the refracted ray.
 *
 *  Used to get a screen position to sample the grabpass for distortion in a way that simulates real refraction (but with
 *  a fixed ray length) instead of simply shifting the uvs by the normal map
 *
 *  @param viewDir  Normalized vector pointing from the camera towards wPos
 *  @param wPos     Worldspace position of the pixel
 *  @param wNormal  Normal direction
 *  @param rIndex   Index of refraction
 *  @param power    Distance along the refracted ray to get the position of
 *
 *  @return Worldspace position of a point power meters along a ray refracted from viewDir about wNormal at wPos.
 *          If the refraction angle is greater than the angle of total internal reflection, returns infinity. 
 */
float4 getRefractedPos(float3 viewDir, float4 wPos, float3 wNormal, float rIndex, const float power)
{
    float3 refracted = refract(viewDir, wNormal, 1.0 / rIndex);
    if (refracted.x == 0.0 && refracted.y == 0.0 && refracted.z == 0.0)
    {
        return float4(1.#INF, 0, 0, 1);
    }
    refracted = normalize(refracted);

    float4 offsetPos = wPos + float4(refracted * power, 0);
    return offsetPos;
}


/** @brief Given an offset position from getRefractedPos and the original pixel's worldspace position,
 *          calculate the screenspace positions of each and interpolate the offset position's screen
 * 
 */
float4 getRefractedUVs(float4 offsetPos, float4 wPos)
{
    float4 sPos = ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, offsetPos));
    float4 sPos1 = ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, wPos));
    float2 UV = sPos.xy / sPos.w;
    float2 UV1 = sPos1.xy / sPos1.w;
    float smoothLerp = smoothstep(0.3, -0.15, UV.y);
    UV.y = lerp(UV.y, UV1.y, smoothLerp);

    return float4(UV, UV1);
}

float4 getRefractedColor(float4 offsetPos, float4 wPos, float3 normal, float facing, float minFog, PARAM_TEXTURE2D_X(GrabPass))
{
    float4 UVs = getRefractedUVs(offsetPos, wPos);
    float2 UV = UVs.xy;
    float2 UV1 = UVs.zw;
    float depthDiff = getDepthDifference(wPos.xyz, offsetPos.xyz, normal, UV, facing);
#ifdef SOFTPARTICLES_ON
    UNITY_BRANCH if (depthDiff < -0.05)
    {
        depthDiff = getDepthDifference(wPos.xyz, offsetPos.xyz, normal, UV1, facing);
        UV.y = UV1.y;
    }
    float FrontFade = saturate(1.0 - (1.0 - minFog) / (exp(depthDiff * _fogDepth)));
#else
    float FrontFade = minFog;
#endif
    //FrontFade = sqrt(FrontFade);
    float4 finalColor = SAMPLE_TEXTURE2D_X_LOD(GrabPass, samplerGrabPass, UV, 0);
    finalColor.rgb = (1.0 - FrontFade) * finalColor.rgb + FrontFade * _DepthColor.rgb;
    //finalColor.rgb = lerp(finalColor.rgb,  _BaseColor.rgb, power*FrontFade);
    /*
     * if refracted is (0,0,0), then we have total internal reflection and we should
     * be 100% reflective. In order to signal this, we'll give final color a negative
     * alpha
     */
    finalColor.a = _ReflectionStr;
    return finalColor;
}