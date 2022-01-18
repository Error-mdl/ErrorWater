/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/* TEXTURE2DARRAY FLIPBOOK TEXTURE SAMPLING                                  */
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/


/** @brief Samples a flipbook animation stored in a texture2D
 *
 *  Calculates the current and next frame for the current time at a given framerate, then samples the
 *  two frames in the array and interpolates between them based on the time
 *
 *  @param texture1		Output value which will contain the texture sample
 *  @param array		Texture array to sample from
 *	@param samplerArray Sampler state to use when sampling the array
 *  @param uv1			UV coordinates to sample at
 *  @param numFrames	Number of frames in the array
 *  @param framerate	Framerate of the animation
 */

inline void FBSample(out float4 texture1,
    Texture2DArray array, const sampler samplerArray, const float2 uv1, const uint numFrames, const float framerate)
{
    uint frame = ((uint)floor(_Time[1] * framerate)) % numFrames;
    uint frame2 = frame == numFrames - 1 ? 0 : frame + 1; // probably faster than doing another modulo?
    float4 sample1 = array.Sample(samplerArray, float3(uv1, frame));
    float4 sample2 = array.Sample(samplerArray, float3(uv1, frame2));
    texture1 = lerp(sample1, sample2, frac(_Time[1] * framerate));
}

/** @brief Samples mip 0 of a flipbook animation stored in a texture2D, only used for vertex offsets so it only outputs the RGB component
 *
 *  Calculates the current and next frame for the current time at a given framerate, then samples mip 0 of the
 *  two frames in the array and interpolates between them based on the time
 *
 *  @param texture1		Output value which will contain the texture sample
 *  @param array		Texture array to sample from
 *	@param samplerArray Sampler state to use when sampling the array
 *  @param uv1			UV coordinates to sample at
 *  @param numFrames	Number of frames in the array
 *  @param framerate	Framerate of the animation
 */

inline void FBSampleLevel(out float3 texture1,
    Texture2DArray array, const sampler samplerArray, const float2 uv1, const uint numFrames, const float framerate)
{
    uint frame = ((uint)floor(_Time[1] * framerate)) % numFrames;
    uint frame2 = frame == numFrames - 1 ? 0 : frame + 1; // probably faster than doing another modulo?
    float3 sample1 = array.SampleLevel(samplerArray, float3(uv1, frame), 0).xyz;
    float3 sample2 = array.SampleLevel(samplerArray, float3(uv1, frame2), 0).xyz;
    texture1 = lerp(sample1, sample2, frac(_Time[1] * framerate));
}

/** @brief Samples a flipbook animation stored in a texture2D at two different UVs for flowmapping
 *
 *  Calculates the current and next frame for the current time at a given framerate, then for each UV coordinate
 *  samples the two frames in the array and interpolates between them based on the time
 *
 *  @param texture1		Output value which will contain the texture sample at uv1
 *  @param texture2		Output value which will contain the texture sample at uv2
 *  @param array		Texture array to sample from
 *	@param samplerArray Sampler state to use when sampling the array
 *  @param uv1			First UV coordinates to sample at
 *  @param uv2			Second UV coordinates to sample at
 *  @param numFrames	Number of frames in the array
 *  @param framerate	Framerate of the animation
 */

inline void FBSampleFlow(out float4 texture1, out float4 texture2,
    Texture2DArray array, const sampler samplerArray, float2 uv1, float2 uv2, const float numFrames, const float framerate)
{
    float frame = floor(fmod(_Time[1] * framerate, numFrames));
    float frame2 = frame >= numFrames - 1 ? 0.0 : frame + 1.0; // probably faster than doing another fmod?
    float4 sample1 = array.Sample(samplerArray, float3(uv1, frame));
    float4 sample2 = array.Sample(samplerArray, float3(uv1, frame2));
    texture1 = lerp(sample1, sample2, frac(_Time[1] * framerate));
    sample1 = array.Sample(samplerArray, float3(uv2, frame));
    sample2 = array.Sample(samplerArray, float3(uv2, frame2));
    texture2 = lerp(sample1, sample2, frac(_Time[1] * framerate));
}

/** @brief Samples mip 0 of a flipbook animation stored in a texture2D at two different UVs for flowmapping,
 *  Only used for vertex offsets so it only outputs the RGB component
 *
 *  Calculates the current and next frame for the current time at a given framerate, then for each UV coordinate
 *  samples mip 0 of the two frames in the array and interpolates between them based on the time
 *
 *  @param texture1		Output value which will contain the texture sample at uv1
 *  @param texture2		Output value which will contain the texture sample at uv2
 *  @param array		Texture array to sample from
 *	@param samplerArray Sampler state to use when sampling the array
 *  @param uv1			First UV coordinates to sample at
 *  @param uv2			Second UV coordinates to sample at
 *  @param numFrames	Number of frames in the array
 *  @param framerate	Framerate of the animation
 */

inline void FBSampleLevelFlow(out float3 texture1, out float3 texture2,
    Texture2DArray array, const sampler samplerArray, float2 uv1, float2 uv2, const float numFrames, const float framerate)
{
    float frame = floor(fmod(_Time[1] * framerate, numFrames));
    float frame2 = frame >= numFrames - 1 ? 0.0 : frame + 1.0; // probably faster than doing another fmod?
    float3 sample1 = array.SampleLevel(samplerArray, float3(uv1, frame), 0).xyz;
    float3 sample2 = array.SampleLevel(samplerArray, float3(uv1, frame2), 0).xyz;
    texture1 = lerp(sample1, sample2, frac(_Time[1] * framerate));
    sample1 = array.SampleLevel(samplerArray, float3(uv2, frame), 0);
    sample2 = array.SampleLevel(samplerArray, float3(uv2, frame2), 0);
    texture2 = lerp(sample1, sample2, frac(_Time[1] * framerate));
}



/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/* FLOWMAP FUNCTIONS                                                         */
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/

/** @brief Samples the flowmap at a given uv and remaps the red-green values from 0-1 to -1 to 1
 *
 *  @param flowMap Flowmap texture
 *  @param sampler_flowMap Sampler state to use when sampling the flowmap
 *  @param uv UV coordinates to sample the flowmap at
 *
 *  @return Flowmap vector indicating direction and speed of the flow.
 */
float2 sampleFlowmap(Texture2D flowMap, sampler sampler_flowMap, const float2 uv)
{
    float2 flow = (2.0 * flowMap.SampleLevel(sampler_flowMap, uv, 0).rg) + float2(-0.996078431372549, -0.996078431372549); // 8 bit textures store 127/255 as the closest approx to 0.5
    flow.g = -flow.g;
    return flow;
}

/** @brief Calculates the value of a 1 amplitude sawtooth wave for a given x
 *
 *  @param x Input value
 *  @param p Period of the sawtooth wave
 *
 *  @return height of the sawtooth wave at x
 */
float sawtoothwave(float x, float p)
{
    return (x / p - floor(x / p));
}

/** @brief Calculates the value of a 1 amplitude triangle wave for a given x
 *
 *  @param x Input value
 *  @param p Period of the triangle wave
 *
 *  @return height of the triangle wave at x
 */
float trianglewave(float x, float p)
{
    return 2 * abs(x / p - floor(x / p + 0.5));
}

/** @brief Calculates UV offsets and blend weights for flowmapping
 *
 *  @param uvIn     Original uvs of the mesh
 *  @param uv1      Output float2 containing the the first set of offset UVs
 *  @param uv2      Output float2 containing the the second set of offset UVs
 *  @param weights  Output float2 containing the blending weights associated with the two UV offsets
 *  @param flow     Flow vector determining the direction and speed of the flow movement
 */

void CalcFlowUVsAndWeights(const float2 uvIn, out float2 uv1, out float2 uv2, out float2 weights, const float2 flow)
{
    float time1 = _Time[1] * 0.25;
    float saw1 = sawtoothwave(time1, 1.0);
    float saw2 = sawtoothwave(0.5 + time1, 1.0);
    uv1 = (0.1 * (flow * saw1)) + uvIn;
    uv2 = (0.1 * (flow * saw2)) + uvIn;
    weights.x = trianglewave(time1, 1.0);
    weights.y = 1.0 - weights.x;
}

/** @brief Samples vertex offsets from a flipbook texture array, offset and blended according to a flowmap
 *
 *  @param vArray       Texture array containing the vertex offset animation
 *  @param flowMap      Flowmap texture
 *  @param samplerMain  Sampler state to use when sampling both the flowmap and the texture array
 *  @param uvArray      uv coordinates to sample the vertex offset array at
 *  @param uvFlowmap    uv coordinates to sample the flowmap at
 *  @param arrayLen     Total number of frames in the texture array
 *  @param frameRate    Frame rate to flip through the frames in the array
 *  @param flowSpeed    Multiplier for how fast the flow should scroll
 *
 *  @return Vertex offset read from the array at the current frame blended and offset by the flowmap
 */
float3 FBVertOffsetFlow(Texture2DArray vArray, Texture2D flowMap, sampler samplerMain, const float2 uvArray, const float2 uvFlowmap, const float arrayLen,
    const float frameRate, const float flowSpeed)
{
    float2 flow = sampleFlowmap(flowMap, samplerMain, uvFlowmap);
    flow *= flowSpeed;

    float2 uv1, uv2, weights;
    CalcFlowUVsAndWeights(uvArray, uv1, uv2, weights, flow);

    float3 vOffset1, vOffset2;
    FBSampleLevelFlow(vOffset1, vOffset2, vArray, samplerMain, uv1, uv2, arrayLen, frameRate);
    vOffset1.rgb = mad(2, vOffset1.rgb, -1);
    vOffset2.rgb = mad(2, vOffset2.rgb, -1);

    return (weights.x * vOffset1.xyz + weights.y * vOffset2.xyz);
}

/** @brief Samples normals from a flipbook texture array, offset and blended according to a flowmap
 *
 *  @param vArray       Texture array containing the vertex offset animation
 *  @param flowMap      Flowmap texture
 *  @param samplerArray Sampler state to use when sampling both the flowmap and the texture array
 *  @param uvArray      uv coordinates to sample the vertex offset array at
 *  @param uvFlowmap    uv coordinates to sample the flowmap at
 *  @param arrayLen     Total number of frames in the texture array
 *  @param frameRate    Frame rate to flip through the frames in the array
 *  @param flowSpeed    Multiplier for how fast the flow should scroll
 *
 *  @return Tangent-space normal read from the array at the current frame and blended and offset by the flowmap
 */
float3 FBNormalFlow(Texture2DArray nArray, const sampler samplerMain, Texture2D flowMap, const float2 uvArray, const float2 uvFlowmap, const float arrayLen,
    const float frameRate, const float flowSpeed)
{
    float2 flow = sampleFlowmap(flowMap, samplerMain, uvFlowmap);
    flow *= flowSpeed;

    float2 uv1, uv2, weights;
    CalcFlowUVsAndWeights(uvArray, uv1, uv2, weights, flow);

    float4 tnormal1, tnormal2;

    FBSampleFlow(tnormal1, tnormal2, nArray, samplerMain, uv1, uv2, arrayLen, frameRate);
    tnormal1.xyz = UnpackNormal(tnormal1);
    tnormal2.xyz = UnpackNormal(tnormal2);
    return normalize(weights.x * tnormal1.xyz + weights.y * tnormal2.xyz);
}
