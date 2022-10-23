VertOut vert(
#ifdef TESSELATION_VARIANT
	TessIn v
#else
	VertIn v
#endif
)
{
	VertOut o;
#ifndef TESSELATION_VARIANT
	UNITY_SETUP_INSTANCE_ID(v);
#endif
	UNITY_INITIALIZE_OUTPUT(VertOut, o);
	UNITY_TRANSFER_INSTANCE_ID(v, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
	
	half3 wNormal = normalize(UnityObjectToWorldNormal(v.normal));

	// Tangent info for calculating world-space normals from a normal map
	float3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
	float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
	float3 bitangent = cross(v.normal, v.tangent.xyz) * tangentSign;
	float3 wBitangent = UnityObjectToWorldDir(bitangent);

	float2 uvArray = v.uv.xy * _BumpArray_ST.xy;

#ifdef TESSELATION_VARIANT
	#ifdef _FLOWMAP_ENABLED
		float2 uvFlow = TRANSFORM_TEX(v.uv2.xy, _FlowMap);
		float3 rawOffset = FBVertOffsetFlow(_OffsetArray, _FlowMap, sampler_OffsetArray, uvArray, uvFlow, _ArrayLen, _BumpArrayFR, _flowSpeed);
	#else
		float3 rawOffset;
		FBSampleLevel(rawOffset, _OffsetArray, sampler_OffsetArray, uvArray, _ArrayLen, _BumpArrayFR);
	#endif

	v.vertex.xyz += (rawOffset.z - 0.5) * v.normal * _OffsetScaleV * v.color.r;
	v.vertex.xyz -= (rawOffset.x * normalize(v.tangent.xyz) / _BumpArray_ST.x + rawOffset.y * normalize(bitangent) / _BumpArray_ST.y) * _OffsetScaleH * v.color.r;
	v.uv -= rawOffset.xy * _OffsetScaleH / (_BumpArray_ST.xy * v.uvToObj) * v.color.r;
#endif

	o.vertex = UnityObjectToClipPos(v.vertex);

	o.uv0.xy = v.uv;//v.vertex.xy;
	o.uv0.zw = v.uv1;
	o.uv2.xy = v.uv2;
	o.uv2.z = wNormal.z;
	o.tspace0 = float4(wTangent.x, wBitangent.x, wNormal.x, wTangent.z);
	o.tspace1 = float4(wTangent.y, wBitangent.y, wNormal.y, wBitangent.z);
	UNITY_TRANSFER_FOG(o, o.vertex);
	o.wPos = mul(unity_ObjectToWorld, v.vertex);
	o.vColor = v.color;
	return o;
}
