
struct VertIn
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float2 uv2 : TEXCOORD2;
	
	#ifdef TESSELATION_VARIANT
	float2 uvToObj : TEXCOORD3;
	#endif

	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float4 color: COLOR;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	//UNITY_VERTEX_OUTPUT_STEREO
};

struct TessIn
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float2 uv2 : TEXCOORD2;

#ifdef TESSELATION_VARIANT
	float2 uvToObj : TEXCOORD3;
#endif

	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float4 color: COLOR;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};

struct VertOut
{
	float4 vertex : SV_POSITION;
	float4 uv0 : TEXCOORD0; // xy is uv0, zw is uv1
	float3 uv2 : TEXCOORD1; // xy is uv2, w is tspace.z;
	float4 tspace0 : TEXCOORD2; // xyz is tspace0, w is tspace2.x 
	float4 tspace1 : TEXCOORD3; // xyz is tspace1, w is tspace2.y 
	UNITY_FOG_COORDS(4)
	float4 wPos : TEXCOORD5;
	float4 vColor : COLOR;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};