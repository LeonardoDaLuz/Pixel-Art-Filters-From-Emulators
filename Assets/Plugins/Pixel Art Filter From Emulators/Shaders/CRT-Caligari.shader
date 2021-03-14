// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/CRT Caligari"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}

	decal("decal (RGB)", 2D) = "white" {} //you should also set this in scripting with material.SetTexture ("decal", yourDecalTexture)
	texture_size("texture_size", Vector) = (256,224,0,0)
	//	video_size("texture_size", Vector) = (256,224,0,0)
	//	output_size("texture_size", Vector) = (256,224,0,0)
		
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

#ifdef PARAMETER_UNIFORM
		uniform float SPOT_WIDTH;
	uniform float SPOT_HEIGHT;
	uniform float COLOR_BOOST;
	uniform float InputGamma;
	uniform float OutputGamma;
#else
		// 0.5 = the spot stays inside the original pixel
		// 1.0 = the spot bleeds up to the center of next pixel
#define SPOT_WIDTH  0.9
#define SPOT_HEIGHT 0.65
		// Used to counteract the desaturation effect of weighting.
#define COLOR_BOOST 1.45
		// Constants used with gamma correction.
#define InputGamma 2.4
#define OutputGamma 2.2
#endif

#include "compat_includes.inc"
		/*
		Phosphor shader - Copyright (C) 2011 caligari.

		Ported by Hyllian.

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
		/*
		Leonardo da Luz Pinto's Phosphor shader CRT-Caligari shader Adaptation to Unity ShaderLab

		Copyright (C) 2018 Leo Luz - leodluz@yahoo.com/leoluzprog@gmail.com

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in
		all copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
		THE SOFTWARE.

		*/
	uniform float4x4 modelViewProj;

		uniform half4 _Color;
	uniform sampler2D decal : TEXUNIT0;

	float2 texture_size; // set from outside the shader ( THIS NOTE WAS MADE BY SONOSHEE)
	float2 output_size = float2(0, 0);
	float2 video_size = float2(0, 0);



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
		float2 texcoord : TEXCOORD0;
		float2 onex : TEXCOORD1;
		float2 oney : TEXCOORD2;

	};




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

		OUT.texcoord = v.texcoord;
		OUT.onex = float2(1.0 / texture_size.x, 0.0);
		OUT.oney = float2(0.0, 1.0 /texture_size.y);

		return OUT;




	}
#define GAMMA_IN(color)     pow(color, float4(InputGamma, InputGamma, InputGamma, InputGamma))
#define GAMMA_OUT(color)    pow(color, float4(1.0 / OutputGamma, 1.0 / OutputGamma, 1.0 / OutputGamma, 1.0 / OutputGamma))

#define TEX2D(coords)	GAMMA_IN( COMPAT_SamplePoint(s_p, coords) )

	// Macro for weights computing
#define WEIGHT(w) \
	if(w>1.0) w=1.0; \
	w = 1.0 - w * w; \
	w = w * w;

	float4 crt_caligari(COMPAT_Texture2D(s_p), float2 texCoord, float2 texture_size, float2 onex, float2 oney)
	{
		float2 coords = (texCoord * texture_size);
		float2 pixel_center = floor(coords) + float2(0.5, 0.5);
		float2 texture_coords = pixel_center / texture_size;

		float4 color = TEX2D(texture_coords);

		float dx = coords.x - pixel_center.x;

		float h_weight_00 = dx / SPOT_WIDTH;
		WEIGHT(h_weight_00);

		color *= float4(h_weight_00, h_weight_00, h_weight_00, h_weight_00);

		// get closest horizontal neighbour to blend
		float2 coords01;
		if (dx>0.0) {
			coords01 = onex;
			dx = 1.0 - dx;
		}
		else {
			coords01 = -onex;
			dx = 1.0 + dx;
		}
		float4 colorNB = TEX2D(texture_coords + coords01);

		float h_weight_01 = dx / SPOT_WIDTH;
		WEIGHT(h_weight_01);

		color = color + colorNB * float4(h_weight_01, h_weight_01, h_weight_01, h_weight_01);

		//////////////////////////////////////////////////////
		// Vertical Blending
		float dy = coords.y - pixel_center.y;
		float v_weight_00 = dy / SPOT_HEIGHT;
		WEIGHT(v_weight_00);
		color *= float4(v_weight_00, v_weight_00, v_weight_00, v_weight_00);

		// get closest vertical neighbour to blend
		float2 coords10;
		if (dy>0.0) {
			coords10 = oney;
			dy = 1.0 - dy;
		}
		else {
			coords10 = -oney;
			dy = 1.0 + dy;
		}
		colorNB = TEX2D(texture_coords + coords10);

		float v_weight_10 = dy / SPOT_HEIGHT;
		WEIGHT(v_weight_10);

		color = color + colorNB * float4(v_weight_10 * h_weight_00, v_weight_10 * h_weight_00, v_weight_10 * h_weight_00, v_weight_10 * h_weight_00);

		colorNB = TEX2D(texture_coords + coords01 + coords10);

		color = color + colorNB * float4(v_weight_10 * h_weight_01, v_weight_10 * h_weight_01, v_weight_10 * h_weight_01, v_weight_10 * h_weight_01);

		color *= float4(COLOR_BOOST, COLOR_BOOST, COLOR_BOOST, COLOR_BOOST);


		return clamp(GAMMA_OUT(color), 0.0, 1.0);
	}
	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{ 
		return crt_caligari(decal, VAR.texcoord, texture_size, VAR.onex, VAR.oney);
	}


		ENDCG
	}
	}
		FallBack "Diffuse"
}