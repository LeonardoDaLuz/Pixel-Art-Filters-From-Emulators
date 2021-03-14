// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/2xSal-Level-2-Two-Passes"
{
	Properties
	{
		texture_size("texture_size", Vector) = (256,224,0,0)
	decal("decal (RGB)", 2D) = "white" {} //you should also set this in scripting with material.SetTexture ("decal", yourDecalTexture)
	//secondPassScale("Second Pass Scale", Float) = 2;
	}
		SubShader
	{
		Tags{ "RenderType" = "Opaque" }
		///////////////////////////////////
		Pass
	{
		CGPROGRAM
		// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices ( THIS NOTE WAS MADE BY UNITY)
#pragma exclude_renderers gles // NOTE : this was added automatically by Unity each time I compile the shader ( THIS NOTE WAS MADE BY SONOSHEE)
#include "UnityCG.cginc"

#pragma vertex main_vertex
#pragma fragment main_fragment
#pragma target 3.0
#include "compat_includes.inc"
		/*
		Copyright (C) 2007 guest(r) - guest.r@gmail.com

		This program is free software; you can redistribute it and/or
		modify it under the terms of the GNU General Public License
		as published by the Free Software Foundation; either version 2
		of the License, or (at your option) any later version.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.

		You should have received a copy of the GNU General Public License
		along with this program; if not, write to the Free Software
		Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
		*/

	uniform sampler2D decal : TEXUNIT0;

	float2 texture_size; // set from outside the shader ( THIS NOTE WAS MADE BY SONOSHEE)




	//---------------------------------------
	// Input Pixel Mapping:  --|21|22|23|--
	//                       19|06|07|08|09
	//                       18|05|00|01|10
	//                       17|04|03|02|11
	//                       --|15|14|13|--
	//
	// Output Pixel Mapping:    06|07|08
	//                          05|00|01
	//                          04|03|02


	struct out_vertex
	{
		float4 position : POSITION;

		float2 texCoord : TEXCOORD0;

	};
	float4 two_xsal_lvl2(float2 texture_size, float2 texCoord, COMPAT_Texture2D(decal))
	{
		float2 texsize = texture_size;
		float dx = 0.25 / texsize.x;
		float dy = 0.25 / texsize.y;
		float3 dt = float3(1.0, 1.0, 1.0);

		float4 yx = float4(dx, dy, -dx, -dy);
		float4 xh = yx*float4(3.0, 1.0, 3.0, 1.0);
		float4 yv = yx*float4(1.0, 3.0, 1.0, 3.0);

		float3 c11 = COMPAT_SamplePoint(decal, texCoord).xyz;
		float3 s00 = COMPAT_SamplePoint(decal, texCoord + yx.zw).xyz;
		float3 s20 = COMPAT_SamplePoint(decal, texCoord + yx.xw).xyz;
		float3 s22 = COMPAT_SamplePoint(decal, texCoord + yx.xy).xyz;
		float3 s02 = COMPAT_SamplePoint(decal, texCoord + yx.zy).xyz;
		float3 h00 = COMPAT_SamplePoint(decal, texCoord + xh.zw).xyz;
		float3 h20 = COMPAT_SamplePoint(decal, texCoord + xh.xw).xyz;
		float3 h22 = COMPAT_SamplePoint(decal, texCoord + xh.xy).xyz;
		float3 h02 = COMPAT_SamplePoint(decal, texCoord + xh.zy).xyz;
		float3 v00 = COMPAT_SamplePoint(decal, texCoord + yv.zw).xyz;
		float3 v20 = COMPAT_SamplePoint(decal, texCoord + yv.xw).xyz;
		float3 v22 = COMPAT_SamplePoint(decal, texCoord + yv.xy).xyz;
		float3 v02 = COMPAT_SamplePoint(decal, texCoord + yv.zy).xyz;

		float m1 = 1.0 / (dot(abs(s00 - s22), dt) + 0.00001);
		float m2 = 1.0 / (dot(abs(s02 - s20), dt) + 0.00001);
		float h1 = 1.0 / (dot(abs(s00 - h22), dt) + 0.00001);
		float h2 = 1.0 / (dot(abs(s02 - h20), dt) + 0.00001);
		float h3 = 1.0 / (dot(abs(h00 - s22), dt) + 0.00001);
		float h4 = 1.0 / (dot(abs(h02 - s20), dt) + 0.00001);
		float v1 = 1.0 / (dot(abs(s00 - v22), dt) + 0.00001);
		float v2 = 1.0 / (dot(abs(s02 - v20), dt) + 0.00001);
		float v3 = 1.0 / (dot(abs(v00 - s22), dt) + 0.00001);
		float v4 = 1.0 / (dot(abs(v02 - s20), dt) + 0.00001);

		float3 t1 = 0.5*(m1*(s00 + s22) + m2*(s02 + s20)) / (m1 + m2);
		float3 t2 = 0.5*(h1*(s00 + h22) + h2*(s02 + h20) + h3*(h00 + s22) + h4*(h02 + s20)) / (h1 + h2 + h3 + h4);
		float3 t3 = 0.5*(v1*(s00 + v22) + v2*(s02 + v20) + v3*(v00 + s22) + v4*(v02 + s20)) / (v1 + v2 + v3 + v4);

		float k1 = 1.0 / (dot(abs(t1 - c11), dt) + 0.00001);
		float k2 = 1.0 / (dot(abs(t2 - c11), dt) + 0.00001);
		float k3 = 1.0 / (dot(abs(t3 - c11), dt) + 0.00001);

		return float4((k1*t1 + k2*t2 + k3*t3) / (k1 + k2 + k3), 1.0);
	}

	//VERTEX_SHADER
	out_vertex main_vertex(appdata_base v)
	{
		out_vertex OUT;

		OUT.position = UnityObjectToClipPos(v.vertex);


		float2 ps = float2(1.0 / texture_size.x, 1.0 / texture_size.y);
		float dx = ps.x;
		float dy = ps.y;

		// A1 B1 C1
		// A0 A B C C4
		// D0 D E F F4
		// G0 G H I I4
		// G5 H5 I5

		// This line fix a bug in ATI cards. ( THIS NOTE WAS MADE BY XBR AUTHOR)
		//float2 texCoord = texCoord1 + float2(0.0000001, 0.0000001);

		OUT.texCoord = v.texcoord;


		return OUT;
	}

	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{
		return two_xsal_lvl2(texture_size, VAR.texCoord, decal);
	}


		ENDCG
	}
	GrabPass
	{
		"_BackgroundTexture"
	}
	Pass
	{
		CGPROGRAM
		// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices ( THIS NOTE WAS MADE BY UNITY)
#pragma exclude_renderers gles // NOTE : this was added automatically by Unity each time I compile the shader ( THIS NOTE WAS MADE BY SONOSHEE)
#include "UnityCG.cginc"

#pragma vertex main_vertex
#pragma fragment main_fragment
#pragma target 3.0
#include "compat_includes.inc"


		uniform half4 _Color;
	uniform sampler2D decal : TEXUNIT0;
	sampler2D _BackgroundTexture;

	float2 texture_size; // set from outside the shader ( THIS NOTE WAS MADE BY SONOSHEE)
	const static float secondPassScale = 2;




	struct out_vertex
	{
		float4 position : POSITION;
		float4 color : COLOR;
		float4 texCoord : TEXCOORD0;

	};
	float4 two_xsal_lvl2_pass2(float2 texture_size, float2 texCoord)
	{
		float2 texsize = texture_size;
		float dx = pow(texsize.x, -1.0) * 0.5;
		float dy = pow(texsize.y, -1.0) * 0.5;
		float3 dt = float3(1.0, 1.0, 1.0);

		float2 UL = texCoord + float2(-dx, -dy);
		float2 UR = texCoord + float2(dx, -dy);
		float2 DL = texCoord + float2(-dx, dy);
		float2 DR = texCoord + float2(dx, dy);

		float3 c00 = COMPAT_SamplePoint(_BackgroundTexture, UL).xyz;
		float3 c20 = COMPAT_SamplePoint(_BackgroundTexture, UR).xyz;
		float3 c02 = COMPAT_SamplePoint(_BackgroundTexture, DL).xyz;
		float3 c22 = COMPAT_SamplePoint(_BackgroundTexture, DR).xyz;

		float m1 = dot(abs(c00 - c22), dt) + 0.001;
		float m2 = dot(abs(c02 - c20), dt) + 0.001;

		return float4((m1*(c02 + c20) + m2*(c22 + c00)) / (2.0*(m1 + m2)), 1.0);
	}


	//VERTEX_SHADER
	out_vertex main_vertex(appdata_base v)
	{
		out_vertex OUT;

		OUT.position = UnityObjectToClipPos(v.vertex);
		OUT.color = _Color;

		OUT.texCoord = ComputeGrabScreenPos(OUT.position);


		return OUT;
	}

	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{
		return two_xsal_lvl2_pass2(texture_size*secondPassScale, VAR.texCoord);
	}


		ENDCG
	}
	}
		FallBack "Diffuse"
}