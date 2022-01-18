Shader "Error.mdl/Water/Flipbook Sphere"
{
	Properties
	{
		[Header (Water Normals)]
		[KeywordEnum(Flipbook, Scrolling)] _Type ("Water Normal Animation", float) = 0
		[ShowIf(_TYPE_FLIPBOOK)] _BumpArray("Normal Map Array", 2DArray) = "bump" {}
		[ShowIf(_TYPE_FLIPBOOK)] _ArrayLen ("Normal Map Array Length", int) = 16
		[ShowIf(_TYPE_FLIPBOOK)] _BumpArrayFR("Flipbook Framerate", float) = 8

		[Header(Water Vertex Animation)]
		[KeywordEnum(Tris, Quads)] _Tess("Tesselation", float) = 0
		_OffsetArray("Vertex Offset Map Array", 2DArray) = "bump" {}
		_OffsetScaleV("Vertical Vertex Offset Scale", float) = 0.05
		_OffsetScaleH("Horizontal Vertex Offset Scale", float) = 0.025
		_TessFac("Tesselation Factor", Float) = 8
		_TessMax("Tesselation Max", Float) = 8

		[Space(10)] 
		[KeywordEnum(Enabled, Disabled)] _Flowmap("Flowmap", float) = 0
		_FlowMap("Flowmap Texture", 2D) = "bump" {}
		_flowSpeed("Flowmap Max Speed", Float) = 1.0

		[Header(Reflection and Refraction)]
		_Refraction("Index of Refraction", Range(0.00, 2.0)) = 1.0
		_Power("Power", Range(0.01, 10.0)) = 1.0
		_BumpScale("Reflection Normal Scale", range(0,2)) = 1.0
		_BumpScale2("Refraction Normal Scale", range(0,2)) = 1.0
		_ReflectionStr("Cubemap reflection strength", range(0,1)) = 0.02

		[Header(Fog and Color)]
		_DepthFade("Edge Fade Factor", float) = 0.02
		_BaseColor ("Base Water Color", color) = (1, 1, 1, 1)
		_DepthColor ("Fog Color", color) = (0.5, 0.5, 0.5, 1)
		_fogDepth ("Fog Density", float) = 0.5

		

		
	 [Header(Screen Space Reflection Settings)]
		_NoiseTex("Noise Texture", 2D) = "black" {}
		_alpha("Reflection Strength", Range(0.0, 1.0)) = 1
		_rtint("Reflection Tint Strength", Range(0.0, 1.0)) = 0
		_blur("Blur (does ^2 texture samples!)", Float) = 3
		_MaxSteps("Max Steps", Int) = 100
		_step("Ray step size", Float) = 0.09
		_lrad("Large ray intersection radius", Float) = 0.2
		_srad("Small ray intersection radius", Float) = 0.02
		_edgeFade("Edge Fade", Range(0,1)) = 0.1
	}

	SubShader
	{
		Tags { "Queue" = "Transparent-160" }

		GrabPass
		{
			"_TransparentGrabPass"
		}
			
		Pass
		{
			Cull off
			//Blend One One
			//Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
			#pragma exclude_renderers gles

			#pragma multi_compile_local _FLOWMAP_ENABLED _FLOWMAP_DISABLED
			#pragma multi_compile_local _TESS_TRIS _TESS_QUADS
			#pragma multi_compile _ SOFTPARTICLES_ON


			#pragma vertex TessVert
			#pragma hull MHullProgram
			#pragma domain MDomainProgram

			#pragma fragment frag

			#pragma target 5.0
		
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"
			#include "../../shaders/SphereReflection.cginc"
			#include "../shaders/cginc/water_samplers.cginc"
		
			struct VertIn
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;

				float2 uv1 : TEXCOORD1;
				float2 uv2 : TEXCOORD2;
			
				float2 uvToObj : TEXCOORD4;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 color: COLOR;
			};
		
			struct VertOut
			{
				float4 vertex : SV_POSITION;
				float4 uv0 : TEXCOORD0; // xy is uv0, zw is uv1
				float3 uv2 : TEXCOORD1; // xy is uv2, w is tspace.z;
				float4 tspace0 : TEXCOORD2; // xyz is tspace0, w is tspace2.x 
				float4 tspace1 : TEXCOORD3; // xyz is tspace1, w is tspace2.y 
				float4 wPos : TEXCOORD5;
				float4 vColor : COLOR;
			};
		
			//sampler2D _MainTex;
			//float4 _MainTex_ST;

			UNITY_DECLARE_TEX2DARRAY(_BumpArray);
			UNITY_DECLARE_TEX2DARRAY(_OffsetArray);
			float4 _OffsetArray_TexelSize;
			half4 _BumpArray_ST;

			float _ArrayLen;
			float _BumpArrayFR;

			float _OffsetScaleV;
			float _OffsetScaleH;

			UNITY_DECLARE_TEX2D_NOSAMPLER(_FlowMap);
			float4 _FlowMap_ST;
			float4 _FlowMap_TexelSize;
			float _flowSpeed;
			float _BumpScale;
			float _BumpScale2;
			float _fogDepth;


			Texture2D _NoiseTex;
			float4 _NoiseTex_TexelSize;
			int _dith;
			float _alpha;
			float _blur;

			float _edgeFade;
			half _rtint;
			half _lrad;
			half _srad;
			float _step;
			int _MaxSteps;
			float _ScrollU;
			float _ScrollV;
			float _Refraction;
			float _Power;
			float _ReflectionStr;
			float _DepthFade;
			float4 _Scroll;
			float4 _BaseColor;
			float4 _DepthColor;

			sampler2D _TransparentGrabPass;
			float4 _TransparentGrabPass_TexelSize;
			
			sampler2D_float _CameraDepthTexture;
			float4 _CameraDepthTexture_TexelSize;

			#include "../shaders/cginc/water_common.cginc"

			float IsNan_float(float In)
			{
				return (In < 0.0 || In > 0.0 || In == 0.0) ? 0 : 1;
				
			}


			VertOut vert(VertIn v)
			{
				VertOut o;

				
				half3 wNormal = normalize(UnityObjectToWorldNormal(v.normal));
				

				
				// Tangent info for calculating world-space normals from a normal map
				float3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
				float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
				float3 bitangent = cross(v.normal, v.tangent.xyz) * tangentSign;
				float3 wBitangent = UnityObjectToWorldDir(bitangent);
				
				o.tspace0 = float4(wTangent.x, wBitangent.x, wNormal.x, wTangent.z);
				o.tspace1 = float4(wTangent.y, wBitangent.y, wNormal.y, wBitangent.z);

				//o.ray.xyz = mul(UNITY_MATRIX_MV, v.vertex).xyz * float3(-1, -1, 1);
			
				 // put z component of tspace2 into uv.z

				float2 uvArray = v.uv.xy * _BumpArray_ST.xy;

#ifdef _FLOWMAP_ENABLED
				float2 uvFlow = TRANSFORM_TEX(v.uv2.xy, _FlowMap);
				float3 rawOffset = FBVertOffsetFlow(_OffsetArray, _FlowMap, sampler_OffsetArray, uvArray, uvFlow, _ArrayLen, _BumpArrayFR, _flowSpeed);
#else
				float3 rawOffset;
				FBSampleLevel(rawOffset, _OffsetArray, sampler_OffsetArray, uvArray, _ArrayLen, _BumpArrayFR);
#endif

				v.vertex.xyz += rawOffset.z * v.normal * _OffsetScaleV *v.color.r;
				v.vertex.xyz -= (rawOffset.x * normalize(v.tangent.xyz) / _BumpArray_ST.x + rawOffset.y * normalize(bitangent) / _BumpArray_ST.y) * _OffsetScaleH * v.color.r;
				float2 uvoffset = float2(v.uv.x - rawOffset.x * _OffsetScaleH / (_BumpArray_ST.x * v.uvToObj.x) * v.color.r, 
										 v.uv.y - rawOffset.y * _OffsetScaleH / (_BumpArray_ST.y * v.uvToObj.y) * v.color.r );


				o.uv0.xy = uvoffset;//v.vertex.xy;

				o.uv0.zw = v.uv1;
				//o.uv0 = IsNan_float(v.uv3.y) ? float4(1, 1, 1, 1) : o.uv0;
				o.uv2.xy = v.uv2;
				o.uv2.z = wNormal.z;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.wPos = mul(unity_ObjectToWorld, v.vertex);
				o.vColor = v.color;
				return o;
			}

			
			#include "../shaders/cginc/water_tesselation.cginc"

			
			float4 frag(VertOut i, uint facing : SV_IsFrontFace) : SV_Target
			{
				/*
				 * We can't use unity's screen params variable as it is actually wrong
				 * in VR (for some reason the width is smaller by some amount than the
				 * true width. However, we're taking a grabpass and the dimensions of
				 * that texture are the true screen dimensions.
				 */
				#define scrnParams _PostTransparentGrabPass_TexelSize.zw


				float2 uv0 = i.uv0.xy * _BumpArray_ST.xy;
				float2 uv2 = TRANSFORM_TEX(i.uv2.xy, _FlowMap);


	#ifdef _FLOWMAP_ENABLED
				half3 tnormal = FBNormalFlow(_BumpArray, sampler_BumpArray, _FlowMap, uv0, uv2, _ArrayLen, _BumpArrayFR, _flowSpeed);
	#else
				half4 tnormalRaw;
				FBSample(tnormalRaw, _BumpArray, sampler_BumpArray, uv0, _ArrayLen, _BumpArrayFR);
				half3 tnormal = UnpackNormal(tnormalRaw);
	#endif
				half3 tnormal2 = float3(tnormal.xy * _BumpScale2, tnormal.z);
				tnormal.xy *= _BumpScale;

				float4 metallic = float4(0,0,0,1);
				float smoothness = metallic.a;
				float4 albedo = float4(1,1,1,1);
				
			
				tnormal = normalize(tnormal);
				tnormal2 = normalize(tnormal2);

				// Mask for defining what areas can have SSR
				float mask = 1;


				float3 tspace2 = float3(i.tspace0.w, i.tspace1.w, i.uv2.z);

				float3 wNormal;
				wNormal.x = dot(i.tspace0.xyz, tnormal);
				wNormal.y = dot(i.tspace1.xyz, tnormal);
				wNormal.z = dot(tspace2, tnormal);

				float3 wNormal2;
				wNormal2.x = dot(i.tspace0, tnormal2);
				wNormal2.y = dot(i.tspace1, tnormal2);
				wNormal2.z = dot(tspace2, tnormal2);
				
				float refrIndex = _Refraction;
				float3 faceNormal = float3(i.tspace0.z, i.tspace1.z, i.uv2.z);

				//Correct for if we're looking at a back face
				if (!facing)
				{
					refrIndex = 1/refrIndex;
					faceNormal = -faceNormal;
					wNormal = -wNormal;
					wNormal2 = -wNormal2;
				}

				float3 viewDir = normalize(i.wPos.xyz - _WorldSpaceCameraPos);
				float4 rayDir = float4(reflect(viewDir, wNormal).xyz, 0);
				rayDir.xyz = normalize(rayDir.xyz);


				float4 cubemap = getCubemapColor2(i.wPos.xyz, rayDir.xyz, 0.975);

				//cubemap.a = _ReflectionStr;
				
				float depthFade1 = getDepthFade(i.wPos, float3(i.tspace0.z, i.tspace1.z, tspace2.z), facing) * i.vColor.g;

				//cubemap.a *= depthFade1;
				float4 offsetPos = getRefractedPos(viewDir, i.wPos, wNormal2, refrIndex, _Power * depthFade1 * depthFade1 );


				float depthFade; 
				float4 BaseColor; 
				float4 refract;
				float4 output;
				if (offsetPos.x != 1.#INF)
				{
					BaseColor = lerp(float4(1, 1, 1, 1), _BaseColor, depthFade1);
					refract = getRefractedColor(offsetPos, i.wPos, float3(i.tspace0.z, i.tspace1.z, tspace2.z), facing, _TransparentGrabPass);

					/* Physically accurate reflectance based on the index of refraction for dielectrics, assuming an incident medium of air
					 
					float cos_incident =  dot(wNormal, rayDir);
					float sin_incident = sqrt(1 - cos_incident*cos_incident);
					float sin_transmitted = sin_incident / _Refraction; // Snell's Law, assuming an incident IOR of 1 (air)
					float cos_transmitted = sqrt(1-sin_transmitted * sin_transmitted);
					float reflectance_parallel = (_Refraction * cos_incident - cos_transmitted) / (_Refraction * cos_incident + cos_transmitted);
					float reflectance_perpendicular = (cos_incident - _Refraction * cos_transmitted) / (cos_incident + _Refraction * cos_transmitted);
					float unpolarized_reflectance = 0.5 * (reflectance_parallel * reflectance_parallel + reflectance_perpendicular * reflectance_perpendicular);
					*/

					//Much simpler formula that is good enough, also allows for physically incorrect reflectance parallel to the normal
					float invCosIncident = 1 - dot(wNormal, rayDir);
					float reflectance = _ReflectionStr + (1 - _ReflectionStr) * (saturate(invCosIncident * invCosIncident * invCosIncident * invCosIncident * invCosIncident));

					//For physically correct parallel reflectance calculated according to the IOR, replace _ReflectionStr with the following.
					/*
					float pReflPara = (_Refraction - 1) / (_Refraction + 1);
					float pReflPerp = (1 - _Refraction) / (_Refraction + 1);
					float reflectionStr = 0.5 * (pReflPara * pReflPara + pReflPerp * pReflPerp);
					*/

					output = lerp(BaseColor * refract, cubemap, reflectance * depthFade1);
				}
				else
				{
					depthFade = 1;
					BaseColor = _BaseColor;
					refract = float4(0, 0, 0, 1);
					output = cubemap;
				}
				//output = float4(frac(i.uv0.xy*10),0,1);
				//output.a *= i.color.r;
				//float refractReflectFactor = refract.a <= 0 ? 1 : _ReflectionStr; 
				return output;
			}
			ENDCG
		}
	}
}