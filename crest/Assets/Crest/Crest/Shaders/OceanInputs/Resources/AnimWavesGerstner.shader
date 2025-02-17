﻿// Crest Ocean System

// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE)

// Adds Gestner waves to world

Shader "Hidden/Crest/Inputs/Animated Waves/Gerstner Global"
{
	SubShader
	{
		Blend [_BlendSrcMode] [_BlendDstMode]
		ZWrite Off
		ZTest Always
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag
			//#pragma enable_d3d11_debug_symbols

			#include "UnityCG.cginc"

			#include "../../OceanGlobals.hlsl"
			#include "../../OceanInputsDriven.hlsl"
			#include "../../OceanHelpersNew.hlsl"
			#include "../../FullScreenTriangle.hlsl"

			Texture2DArray _WaveBuffer;

			CBUFFER_START(CrestPerOceanInput)
			int _WaveBufferSliceIndex;
			float _Weight;
			float _AverageWavelength;
			float _AttenuationInShallows;
			float2 _AxisX;
			float _RespectShallowWaterAttenuation;
			half _MaximumAttenuationDepth;
			CBUFFER_END

			struct Attributes
			{
				uint VertexID : SV_VertexID;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float4 uv_uvWaves : TEXCOORD0;
			};

			Varyings Vert(Attributes input)
			{
				Varyings o;
				o.positionCS = GetFullScreenTriangleVertexPosition(input.VertexID);

				o.uv_uvWaves.xy = GetFullScreenTriangleTexCoord(input.VertexID);

				float2 worldPosXZ = UVToWorld( o.uv_uvWaves.xy, _LD_SliceIndex, _CrestCascadeData[_LD_SliceIndex] );

				// UV coordinate into wave buffer
				float2 wavePos = float2( dot(worldPosXZ, _AxisX), dot(worldPosXZ, float2(-_AxisX.y, _AxisX.x)) );
				float scale = 0.5f * (1 << _WaveBufferSliceIndex);
				o.uv_uvWaves.zw = wavePos / scale;

				return o;
			}

			half4 Frag( Varyings input ) : SV_Target
			{
				float wt = _Weight;

				// Attenuate if depth is less than half of the average wavelength
				const half2 terrainHeight_seaLevelOffset =
					_LD_TexArray_SeaFloorDepth.SampleLevel(LODData_linear_clamp_sampler, float3(input.uv_uvWaves.xy, _LD_SliceIndex), 0.0).xy;
				const half depth = _OceanCenterPosWorld.y - terrainHeight_seaLevelOffset.x + terrainHeight_seaLevelOffset.y;
				half depth_wt = saturate(2.0 * depth / _AverageWavelength);
				if (_MaximumAttenuationDepth < CREST_OCEAN_DEPTH_BASELINE)
				{
					depth_wt = lerp(depth_wt, 1.0, saturate(depth / _MaximumAttenuationDepth));
				}
				const float attenuationAmount = _AttenuationInShallows * _RespectShallowWaterAttenuation;
				wt *= attenuationAmount * depth_wt + (1.0 - attenuationAmount);

				// Sample displacement, rotate into frame
				float3 disp = _WaveBuffer.SampleLevel(sampler_Crest_linear_repeat, float3(input.uv_uvWaves.zw, _WaveBufferSliceIndex), 0).xyz;
				disp.xz = disp.x * _AxisX + disp.z * float2(-_AxisX.y, _AxisX.x);

				return half4(disp, wt);
			}
			ENDCG
		}
	}
}
