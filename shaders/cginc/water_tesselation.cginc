
float _TessFac;
float _TessMax;

/* @brief Dummy vertex program that returns the vertex data unmodified so that
 * the actual computations can be done in the domain program
 *
 * @param v VertIn struct containing the vertex data
 * @return The unchanged VertIn struct
 */
VertIn TessVert(VertIn v)
{
	return v;
}

/* @brief Computes the tesselation factor for an edge from the length of the
 * edge divided by its distance to the camera
 *
 * @param camP0 Position in camera-space of the first vertex of the edge
 * @param camP1 Position in camera-space of the second vertex of the edge
 *
 * @return The tesselation edge factor for the given edge
 */
float edgeFactor(float3 camP0, float3 camP1)
{
	float3 edgeCenter = 0.5 * (camP0.xyz + camP1.xyz);
	float3 edgeDist = length(edgeCenter);
	float edgeLen = length( camP0 - camP1);
	return 	clamp(_TessFac * distance(camP0, camP1) / edgeDist, 0 , _TessMax) * edgeLen;
}


/* @brief Computes the barycentric coordinates of a 2d coordinate in a given triangle
 *
 * @param v1 First vertex of the triangle
 * @param v2 Second vertex of the triangle
 * @param v3 Third vertex of the triangle
 * @param p  Point to compute the barycentric coordinates of
 *
 * @return Barycentric coordinates of p in the triangle (v1, v2, v3)
 */
float3 GetBarycentric(float2 v1, float2 v2, float2 v3, float2 p)
{
	float3 B;
	B.x = ((v2.y - v3.y) * (p.x - v3.x) + (v3.x - v2.x) * (p.y - v3.y)) /
		((v2.y - v3.y) * (v1.x - v3.x) + (v3.x - v2.x) * (v1.y - v3.y));
	B.y = ((v3.y - v1.y) * (p.x - v3.x) + (v1.x - v3.x) * (p.y - v3.y)) /
		((v3.y - v1.y) * (v2.x - v3.x) + (v1.x - v3.x) * (v2.y - v3.y));
	B.z = 1 - B.x - B.y;
	return B;
}

inline float sign2(float s)
{
	return s >= 0 ? 1.0 : -1.0;
}

inline float2 GetWeights(const float2 vec1, const float2 vec2, const float2 vec3)
{
	float d = (vec1.x * vec2.y - vec2.x * vec1.y);
	float b = (vec3.y * vec1.x - vec3.x * vec1.y) / (d + sign(d)*1.0E-15);
	float a = (vec3.x - b * vec2.x) / (vec1.x + sign(vec1.x)*1.0E-15);
	return float2(a, b);
}

inline float2 GetWeightsVert(const float2 vert1, const float2 vert2, const float2 vert3, const float2 vec3)
{
	float2 vec1 = vert1 - vert2;
	float2 vec2 = vert3 - vert2;
	float b = (vec3.y * vec1.x - vec3.x * vec1.y) / (vec1.x * vec2.y - vec2.x * vec1.y);
	float a = (vec3.x - b * vec2.x) / vec1.x;
	return float2(a, b);
}

/* Quad-based tesselation -------------------------------------------------- */
#ifdef _TESS_QUADS
/*-------------------------------------------------------------------------- */

struct TesFact
{
	float edge[4] : SV_TessFactor;
	float inside[2] : SV_InsideTessFactor;
};


TesFact MPatchConstFunc(InputPatch<VertIn, 4> patch)
{
	TesFact f;
	float3 p1, p2, p3;

	p1 = mul(UNITY_MATRIX_MV, patch[3].vertex).xyz;
	p2 = mul(UNITY_MATRIX_MV, patch[0].vertex).xyz;

	f.edge[0] = edgeFactor(p1, p2);

	p3 = mul(UNITY_MATRIX_MV, patch[1].vertex).xyz;
	f.edge[1] = edgeFactor(p2, p3);

	p2 = mul(UNITY_MATRIX_MV, patch[2].vertex).xyz;
	f.edge[2] = edgeFactor(p3, p2);

	f.edge[3] = edgeFactor(p2, p1);
	f.inside[0] = 0.5 * (f.edge[3] + f.edge[1]);
	f.inside[1] = 0.5 * (f.edge[2] + f.edge[0]);
	return f;
}

[UNITY_domain("quad")]
[UNITY_outputcontrolpoints(4)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("fractional_even")]
[UNITY_patchconstantfunc("MPatchConstFunc")]
VertIn MHullProgram(InputPatch<VertIn, 4> patch,
	uint id : SV_OutputControlPointID)
{
	return patch[id];
}


[UNITY_domain("quad")]
VertOut MDomainProgram(
	TesFact factors,
	OutputPatch<VertIn, 4> patch,
	float2 barycentrCoords : SV_DomainLocation
) {
	VertIn data;
	/*
	float2 uv01 = patch[1].uv - patch[0].uv;
	float2 uv03 = patch[3].uv - patch[0].uv;
	float3 vt01 = patch[1].vertex.xyz - patch[0].vertex.xyz;
	float3 vt03 = patch[3].vertex.xyz - patch[0].vertex.xyz;
	float2 bx = GetWeights(uv01, uv03, float2(1,0));
	float2 by = GetWeights(uv01, uv03, float2(0,1));
	
	float offsetX0 = length(bx.x * vt01 + bx.y * vt03);
	float offsetY0 = length(by.x * vt01 + by.y * vt03);
	
	float2 uv12 = patch[2].uv - patch[1].uv;
	float3 vt12 = patch[2].vertex.xyz - patch[1].vertex.xyz;
	
	bx = GetWeights(-uv01, uv02, float2(1,0));
	by = GetWeights(-uv01, uv02, float2(0,1));
	
	float offsetX1 = length(bx.x * (-vt01) + bx.y * vt12);
	float offsetY1 = length(by.x * (-vt01) + by.y * vt12);

	
	data.uvToObj.x = offsetX; 
	data.uvToObj.y = offsetY; 
*/	
	
	float3 bx = GetBarycentric(patch[1].uv, patch[0].uv, patch[3].uv, patch[0].uv + float2(1, 0));
	float3 by = GetBarycentric(patch[1].uv, patch[0].uv, patch[3].uv, patch[0].uv + float2(0, 1));
	float offsetX0 = length(bx.x * patch[1].vertex.xyz + bx.y * patch[0].vertex.xyz + bx.z * patch[3].vertex.xyz);
	float offsetY0 = length(by.x * patch[1].vertex.xyz + by.y * patch[0].vertex.xyz + by.z * patch[3].vertex.xyz);

	bx = GetBarycentric(patch[0].uv, patch[1].uv, patch[2].uv, patch[1].uv + float2(1, 0));
	by = GetBarycentric(patch[0].uv, patch[1].uv, patch[2].uv, patch[1].uv + float2(0, 1));
	float offsetX1 = length(bx.x * patch[0].vertex.xyz + bx.y * patch[1].vertex.xyz + bx.z * patch[2].vertex.xyz);
	float offsetY1 = length(by.x * patch[0].vertex.xyz + by.y * patch[1].vertex.xyz + by.z * patch[2].vertex.xyz);

	bx = GetBarycentric(patch[1].uv, patch[2].uv, patch[3].uv, patch[2].uv + float2(1, 0));
	by = GetBarycentric(patch[1].uv, patch[2].uv, patch[3].uv, patch[2].uv + float2(0, 1));
	float offsetX2 = length(bx.x * patch[1].vertex.xyz + bx.y * patch[2].vertex.xyz + bx.z * patch[3].vertex.xyz);
	float offsetY2 = length(by.x * patch[1].vertex.xyz + by.y * patch[2].vertex.xyz + by.z * patch[3].vertex.xyz);

	bx = GetBarycentric(patch[2].uv, patch[3].uv, patch[0].uv, patch[3].uv + float2(1, 0));
	by = GetBarycentric(patch[2].uv, patch[3].uv, patch[0].uv, patch[3].uv + float2(0, 1));
	float offsetX3 = length(bx.x * patch[2].vertex.xyz + bx.y * patch[3].vertex.xyz + bx.z * patch[0].vertex.xyz);
	float offsetY3 = length(by.x * patch[2].vertex.xyz + by.y * patch[3].vertex.xyz + by.z * patch[0].vertex.xyz);
	
	float xA = lerp(offsetX0, offsetX1, barycentrCoords.x);
	float xB = lerp(offsetX3, offsetX2, barycentrCoords.x);
	data.uvToObj.x = lerp(xA, xB, barycentrCoords.y);

	float yA = lerp(offsetY0, offsetY1, barycentrCoords.x);
	float yB = lerp(offsetY3, offsetY2, barycentrCoords.x);
	data.uvToObj.y = lerp(yA, yB, barycentrCoords.y);
	
	
	
	float3 vA = lerp(patch[0].vertex.xyz, patch[1].vertex.xyz, barycentrCoords.x);
	float3 vB = lerp(patch[3].vertex.xyz, patch[2].vertex.xyz, barycentrCoords.x);
	data.vertex = float4(lerp(vA, vB, barycentrCoords.y), 1);

	float2 uvA = lerp(patch[0].uv, patch[1].uv, barycentrCoords.x);
	float2 uvB = lerp(patch[3].uv, patch[2].uv, barycentrCoords.x);
	data.uv = lerp(uvA, uvB, barycentrCoords.y);

	float2 uv1A = lerp(patch[0].uv1, patch[1].uv1, barycentrCoords.x);
	float2 uv1B = lerp(patch[3].uv1, patch[2].uv1, barycentrCoords.x);
	data.uv1 = lerp(uv1A, uv1B, barycentrCoords.y);

	float2 uv2A = lerp(patch[0].uv2, patch[1].uv2, barycentrCoords.x);
	float2 uv2B = lerp(patch[3].uv2, patch[2].uv2, barycentrCoords.x);
	data.uv2 = lerp(uv2A, uv2B, barycentrCoords.y);

	float3 nA = lerp(patch[0].normal, patch[1].normal, barycentrCoords.x);
	float3 nB = lerp(patch[3].normal, patch[2].normal, barycentrCoords.x);
	data.normal = lerp(nA, nB, barycentrCoords.y);

	float4 tA = lerp(patch[0].tangent, patch[1].tangent, barycentrCoords.x);
	float4 tB = lerp(patch[3].tangent, patch[2].tangent, barycentrCoords.x);
	data.tangent = lerp(tA, tB, barycentrCoords.y);

	float4 cA = lerp(patch[0].color, patch[1].color, barycentrCoords.x);
	float4 cB = lerp(patch[3].color, patch[2].color, barycentrCoords.x);
	data.color = lerp(cA, cB, barycentrCoords.y);
	
	return vert(data);
}


/* Triangle-based tesselation ---------------------------------------------- */
#elif defined(_TESS_TRIS)
/*-------------------------------------------------------------------------- */

struct TesFact
{
	float edge[3] : SV_TessFactor;
	float inside : SV_InsideTessFactor;
};



TesFact MPatchConstFunc(InputPatch<VertIn, 3> patch)
{
	TesFact f;
	float3 p0, p1, p2;

	p0 = mul(UNITY_MATRIX_MV, patch[0].vertex).xyz;
	p1 = mul(UNITY_MATRIX_MV, patch[1].vertex).xyz;
	p2 = mul(UNITY_MATRIX_MV, patch[2].vertex).xyz;

	f.edge[0] = edgeFactor(p1, p2);	
	f.edge[1] = edgeFactor(p2, p0);
	f.edge[2] = edgeFactor(p0, p1);

	f.inside = 0.33333 * (f.edge[0] + f.edge[1] + f.edge[2]);
	return f;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("fractional_even")]
[UNITY_patchconstantfunc("MPatchConstFunc")]
VertIn MHullProgram(InputPatch<VertIn, 3> patch,
	uint id : SV_OutputControlPointID)
{
	return patch[id];
}

			float IsNan2_float(float In)
			{
				return (In < 0.0 || In > 0.0 || In == 0.0) ? 0 : 1;
				
			}
[UNITY_domain("tri")]
VertOut MDomainProgram(
	TesFact factors,
	OutputPatch<VertIn, 3> patch,
	float3 barycentrCoords : SV_DomainLocation
) {
	VertIn data;

	#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
		patch[0].fieldName * barycentrCoords.x + \
		patch[1].fieldName * barycentrCoords.y + \
		patch[2].fieldName * barycentrCoords.z;
	
	MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
	//MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
	MY_DOMAIN_PROGRAM_INTERPOLATE(uv1)
	MY_DOMAIN_PROGRAM_INTERPOLATE(uv2)
	MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
	MY_DOMAIN_PROGRAM_INTERPOLATE(tangent)
	MY_DOMAIN_PROGRAM_INTERPOLATE(color)
	data.uv = patch[0].uv * barycentrCoords.x + patch[1].uv * barycentrCoords.y + patch[2].uv * barycentrCoords.z;
	
	float2 uv01 = patch[1].uv - patch[0].uv;
	float2 uv02 = patch[2].uv - patch[0].uv;
	float3 vt01 = patch[1].vertex.xyz - patch[0].vertex.xyz;
	float3 vt02 = patch[2].vertex.xyz - patch[0].vertex.xyz;
	float2 bx = GetWeights(uv01, uv02, float2(1,0));
	float offsetX = length(bx.x * vt01 + bx.y * vt02);
	float2 by = GetWeights(uv01, uv02, float2(0,1));
	float offsetY = length(by.x * vt01 + by.y * vt02);
	UNITY_BRANCH if (IsNan2_float(offsetX) || IsNan2_float(offsetY))
	{
		uv01 = patch[2].uv - patch[1].uv;
		uv02 = patch[0].uv - patch[1].uv;
		vt01 = patch[2].vertex.xyz - patch[1].vertex.xyz;
		vt02 = patch[0].vertex.xyz - patch[1].vertex.xyz;
		bx = GetWeights(uv01, uv02, float2(1,0));
		offsetX = length(bx.x * vt01 + bx.y * vt02);
		by = GetWeights(uv01, uv02, float2(0,1));
		offsetY = length(by.x * vt01 + by.y * vt02);
	}

	data.uvToObj.x = offsetX; 
	data.uvToObj.y = offsetY;  
	
	
	
	return vert(data);
}

#endif