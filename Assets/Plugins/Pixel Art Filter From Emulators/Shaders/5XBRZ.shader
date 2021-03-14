﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/5xBRZ"
{
	Properties
	{
		texture_size("texture_size", Vector) = (256,224,0,0)
	decal("decal (RGB)", 2D) = "white" {} //you should also set this in scripting with material.SetTexture ("decal", yourDecalTexture)
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
		// 5xBRZ shader - Copyright (C) 2014-2016 DeSmuME team
		//
		// This file is free software: you can redistribute it and/or modify
		// it under the terms of the GNU General Public License as published by
		// the Free Software Foundation, either version 2 of the License, or
		// (at your option) any later version.
		//
		// This file is distributed in the hope that it will be useful,
		// but WITHOUT ANY WARRANTY; without even the implied warranty of
		// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		// GNU General Public License for more details.
		//
		// You should have received a copy of the GNU General Public License
		// along with the this software.  If not, see <http://www.gnu.org/licenses/>.


		/*
		Hyllian's xBR-vertex code and texel mapping

		Copyright (C) 2011/2016 Hyllian - sergiogdb@gmail.com

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
		/*
		Leonardo da Luz Pinto's 5xBRZ shader Adaptation to Unity ShaderLab

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
#pragma vertex main_vertex
#pragma fragment main_fragment
#pragma target 3.0
#include "compat_includes.inc"
#define BLEND_NONE 0
#define BLEND_NORMAL 1
#define BLEND_DOMINANT 2
#define LUMINANCE_WEIGHT 1.0
#define EQUAL_COLOR_TOLERANCE 30.0/255.0
#define STEEP_DIRECTION_THRESHOLD 2.2
#define DOMINANT_DIRECTION_THRESHOLD 3.6


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
		float4 t1       : TEXCOORD1;
		float4 t2       : TEXCOORD2;
		float4 t3       : TEXCOORD3;
		float4 t4       : TEXCOORD4;
		float4 t5       : TEXCOORD5;
		float4 t6       : TEXCOORD6;
		float4 t7       : TEXCOORD7;
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

		OUT.texCoord = v.texcoord;
		OUT.t1 = v.texcoord.xxxy + float4(-dx, 0, dx, -2.0*dy); // A1 B1 C1
		OUT.t2 = v.texcoord.xxxy + float4(-dx, 0, dx, -dy); // A B C
		OUT.t3 = v.texcoord.xxxy + float4(-dx, 0, dx, 0); // D E F
		OUT.t4 = v.texcoord.xxxy + float4(-dx, 0, dx, dy); // G H I
		OUT.t5 = v.texcoord.xxxy + float4(-dx, 0, dx, 2.0*dy); // G5 H5 I5
		OUT.t6 = v.texcoord.xyyy + float4(-2.0*dx, -dy, 0, dy); // A0 D0 G0
		OUT.t7 = v.texcoord.xyyy + float4(2.0*dx, -dy, 0, dy); // C4 F4 I4

		return OUT;
	}

	float reduce(const float3 color)
	{
		return dot(color, float3(65536.0, 256.0, 1.0));
	}

	float DistYCbCr(const float3 pixA, const float3 pixB)
	{
		const float3 w = float3(0.2627, 0.6780, 0.0593);
		const float scaleB = 0.5 / (1.0 - w.b);
		const float scaleR = 0.5 / (1.0 - w.r);
		float3 diff = pixA - pixB;
		float Y = dot(diff, w);
		float Cb = scaleB * (diff.b - Y);
		float Cr = scaleR * (diff.r - Y);

		return sqrt(((LUMINANCE_WEIGHT * Y) * (LUMINANCE_WEIGHT * Y)) + (Cb * Cb) + (Cr * Cr));
	}

	bool IsPixEqual(const float3 pixA, const float3 pixB)
	{
		return (DistYCbCr(pixA, pixB) < EQUAL_COLOR_TOLERANCE);
	}

	bool IsBlendingNeeded(const int4 blend)
	{
		return any(!(blend == int4(BLEND_NONE, BLEND_NONE, BLEND_NONE, BLEND_NONE)));
	}
	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{
		float2 f = frac(VAR.texCoord*texture_size);

		//---------------------------------------
		// Input Pixel Mapping:  20|21|22|23|24
		//                       19|06|07|08|09
		//                       18|05|00|01|10
		//                       17|04|03|02|11
		//                       16|15|14|13|12

		float3 src[25];

		src[21] = COMPAT_SamplePoint(decal, VAR.t1.xw).rgb;
		src[22] = COMPAT_SamplePoint(decal, VAR.t1.yw).rgb;
		src[23] = COMPAT_SamplePoint(decal, VAR.t1.zw).rgb;
		src[6] = COMPAT_SamplePoint(decal, VAR.t2.xw).rgb;
		src[7] = COMPAT_SamplePoint(decal, VAR.t2.yw).rgb;
		src[8] = COMPAT_SamplePoint(decal, VAR.t2.zw).rgb;
		src[5] = COMPAT_SamplePoint(decal, VAR.t3.xw).rgb;
		src[0] = COMPAT_SamplePoint(decal, VAR.t3.yw).rgb;
		src[1] = COMPAT_SamplePoint(decal, VAR.t3.zw).rgb;
		src[4] = COMPAT_SamplePoint(decal, VAR.t4.xw).rgb;
		src[3] = COMPAT_SamplePoint(decal, VAR.t4.yw).rgb;
		src[2] = COMPAT_SamplePoint(decal, VAR.t4.zw).rgb;
		src[15] = COMPAT_SamplePoint(decal, VAR.t5.xw).rgb;
		src[14] = COMPAT_SamplePoint(decal, VAR.t5.yw).rgb;
		src[13] = COMPAT_SamplePoint(decal, VAR.t5.zw).rgb;
		src[19] = COMPAT_SamplePoint(decal, VAR.t6.xy).rgb;
		src[18] = COMPAT_SamplePoint(decal, VAR.t6.xz).rgb;
		src[17] = COMPAT_SamplePoint(decal, VAR.t6.xw).rgb;
		src[9] = COMPAT_SamplePoint(decal, VAR.t7.xy).rgb;
		src[10] = COMPAT_SamplePoint(decal, VAR.t7.xz).rgb;
		src[11] = COMPAT_SamplePoint(decal, VAR.t7.xw).rgb;

		float v[9];
		v[0] = reduce(src[0]);
		v[1] = reduce(src[1]);
		v[2] = reduce(src[2]);
		v[3] = reduce(src[3]);
		v[4] = reduce(src[4]);
		v[5] = reduce(src[5]);
		v[6] = reduce(src[6]);
		v[7] = reduce(src[7]);
		v[8] = reduce(src[8]);

		int4 blendResult = int4(BLEND_NONE,BLEND_NONE,BLEND_NONE,BLEND_NONE);

		// Preprocess corners
		// Pixel Tap Mapping: --|--|--|--|--
		//                    --|--|07|08|--
		//                    --|05|00|01|10
		//                    --|04|03|02|11
		//                    --|--|14|13|--

		// Corner (1, 1)
		if (!((v[0] == v[1] && v[3] == v[2]) || (v[0] == v[3] && v[1] == v[2])))
		{
			float dist_03_01 = DistYCbCr(src[4], src[0]) + DistYCbCr(src[0], src[8]) + DistYCbCr(src[14], src[2]) + DistYCbCr(src[2], src[10]) + (4.0 * DistYCbCr(src[3], src[1]));
			float dist_00_02 = DistYCbCr(src[5], src[3]) + DistYCbCr(src[3], src[13]) + DistYCbCr(src[7], src[1]) + DistYCbCr(src[1], src[11]) + (4.0 * DistYCbCr(src[0], src[2]));
			bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_03_01) < dist_00_02;
			blendResult[2] = ((dist_03_01 < dist_00_02) && (v[0] != v[1]) && (v[0] != v[3])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
		}


		// Pixel Tap Mapping: --|--|--|--|--
		//                    --|06|07|--|--
		//                    18|05|00|01|--
		//                    17|04|03|02|--
		//                    --|15|14|--|--
		// Corner (0, 1)
		if (!((v[5] == v[0] && v[4] == v[3]) || (v[5] == v[4] && v[0] == v[3])))
		{
			float dist_04_00 = DistYCbCr(src[17], src[5]) + DistYCbCr(src[5], src[7]) + DistYCbCr(src[15], src[3]) + DistYCbCr(src[3], src[1]) + (4.0 * DistYCbCr(src[4], src[0]));
			float dist_05_03 = DistYCbCr(src[18], src[4]) + DistYCbCr(src[4], src[14]) + DistYCbCr(src[6], src[0]) + DistYCbCr(src[0], src[2]) + (4.0 * DistYCbCr(src[5], src[3]));
			bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_05_03) < dist_04_00;
			blendResult[3] = ((dist_04_00 > dist_05_03) && (v[0] != v[5]) && (v[0] != v[3])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
		}

		// Pixel Tap Mapping: --|--|22|23|--
		//                    --|06|07|08|09
		//                    --|05|00|01|10
		//                    --|--|03|02|--
		//                    --|--|--|--|--
		// Corner (1, 0)
		if (!((v[7] == v[8] && v[0] == v[1]) || (v[7] == v[0] && v[8] == v[1])))
		{
			float dist_00_08 = DistYCbCr(src[5], src[7]) + DistYCbCr(src[7], src[23]) + DistYCbCr(src[3], src[1]) + DistYCbCr(src[1], src[9]) + (4.0 * DistYCbCr(src[0], src[8]));
			float dist_07_01 = DistYCbCr(src[6], src[0]) + DistYCbCr(src[0], src[2]) + DistYCbCr(src[22], src[8]) + DistYCbCr(src[8], src[10]) + (4.0 * DistYCbCr(src[7], src[1]));
			bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_07_01) < dist_00_08;
			blendResult[1] = ((dist_00_08 > dist_07_01) && (v[0] != v[7]) && (v[0] != v[1])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
		}

		// Pixel Tap Mapping: --|21|22|--|--
		//                    19|06|07|08|--
		//                    18|05|00|01|--
		//                    --|04|03|--|--
		//                    --|--|--|--|--
		// Corner (0, 0)
		if (!((v[6] == v[7] && v[5] == v[0]) || (v[6] == v[5] && v[7] == v[0])))
		{
			float dist_05_07 = DistYCbCr(src[18], src[6]) + DistYCbCr(src[6], src[22]) + DistYCbCr(src[4], src[0]) + DistYCbCr(src[0], src[8]) + (4.0 * DistYCbCr(src[5], src[7]));
			float dist_06_00 = DistYCbCr(src[19], src[5]) + DistYCbCr(src[5], src[3]) + DistYCbCr(src[21], src[7]) + DistYCbCr(src[7], src[1]) + (4.0 * DistYCbCr(src[6], src[0]));
			bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_05_07) < dist_06_00;
			blendResult[0] = ((dist_05_07 < dist_06_00) && (v[0] != v[5]) && (v[0] != v[7])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
		}

		float3 dst[25];
		dst[0] = src[0];
		dst[1] = src[0];
		dst[2] = src[0];
		dst[3] = src[0];
		dst[4] = src[0];
		dst[5] = src[0];
		dst[6] = src[0];
		dst[7] = src[0];
		dst[8] = src[0];
		dst[9] = src[0];
		dst[10] = src[0];
		dst[11] = src[0];
		dst[12] = src[0];
		dst[13] = src[0];
		dst[14] = src[0];
		dst[15] = src[0];
		dst[16] = src[0];
		dst[17] = src[0];
		dst[18] = src[0];
		dst[19] = src[0];
		dst[20] = src[0];
		dst[21] = src[0];
		dst[22] = src[0];
		dst[23] = src[0];
		dst[24] = src[0];

		// Scale pixel
		if (IsBlendingNeeded(blendResult))
		{
			float dist_01_04 = DistYCbCr(src[1], src[4]);
			float dist_03_08 = DistYCbCr(src[3], src[8]);
			bool haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v[0] != v[4]) && (v[5] != v[4]);
			bool haveSteepLine = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v[0] != v[8]) && (v[7] != v[8]);
			bool needBlend = (blendResult[2] != BLEND_NONE);
			bool doLineBlend = (blendResult[2] >= BLEND_DOMINANT ||
				!((blendResult[1] != BLEND_NONE && !IsPixEqual(src[0], src[4])) ||
				(blendResult[3] != BLEND_NONE && !IsPixEqual(src[0], src[8])) ||
					(IsPixEqual(src[4], src[3]) && IsPixEqual(src[3], src[2]) && IsPixEqual(src[2], src[1]) && IsPixEqual(src[1], src[8]) && !IsPixEqual(src[0], src[2]))));

			float3 blendPix = (DistYCbCr(src[0], src[1]) <= DistYCbCr(src[0], src[3])) ? src[1] : src[3];
			dst[1] = lerp(dst[1], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.250 : 0.000);
			dst[2] = lerp(dst[2], blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 2.0 / 3.0 : 0.750) : ((haveSteepLine) ? 0.750 : 0.125)) : 0.000);
			dst[3] = lerp(dst[3], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.250 : 0.000);
			dst[9] = lerp(dst[9], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.750 : 0.000);
			dst[10] = lerp(dst[10], blendPix, (needBlend && doLineBlend) ? ((haveSteepLine) ? 1.000 : ((haveShallowLine) ? 0.250 : 0.125)) : 0.000);
			dst[11] = lerp(dst[11], blendPix, (needBlend) ? ((doLineBlend) ? ((!haveShallowLine && !haveSteepLine) ? 0.875 : 1.000) : 0.2306749731) : 0.000);
			dst[12] = lerp(dst[12], blendPix, (needBlend) ? ((doLineBlend) ? 1.000 : 0.8631434088) : 0.000);
			dst[13] = lerp(dst[13], blendPix, (needBlend) ? ((doLineBlend) ? ((!haveShallowLine && !haveSteepLine) ? 0.875 : 1.000) : 0.2306749731) : 0.000);
			dst[14] = lerp(dst[14], blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? 1.000 : ((haveSteepLine) ? 0.250 : 0.125)) : 0.000);
			dst[15] = lerp(dst[15], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.750 : 0.000);
			dst[16] = lerp(dst[16], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.250 : 0.000);
			dst[24] = lerp(dst[24], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.250 : 0.000);


			dist_01_04 = DistYCbCr(src[7], src[2]);
			dist_03_08 = DistYCbCr(src[1], src[6]);
			haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v[0] != v[2]) && (v[3] != v[2]);
			haveSteepLine = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v[0] != v[6]) && (v[5] != v[6]);
			needBlend = (blendResult[1] != BLEND_NONE);
			doLineBlend = (blendResult[1] >= BLEND_DOMINANT ||
				!((blendResult[0] != BLEND_NONE && !IsPixEqual(src[0], src[2])) ||
				(blendResult[2] != BLEND_NONE && !IsPixEqual(src[0], src[6])) ||
					(IsPixEqual(src[2], src[1]) && IsPixEqual(src[1], src[8]) && IsPixEqual(src[8], src[7]) && IsPixEqual(src[7], src[6]) && !IsPixEqual(src[0], src[8]))));

			blendPix = (DistYCbCr(src[0], src[7]) <= DistYCbCr(src[0], src[1])) ? src[7] : src[1];
			dst[7] = lerp(dst[7], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.250 : 0.000);
			dst[8] = lerp(dst[8], blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 2.0 / 3.0 : 0.750) : ((haveSteepLine) ? 0.750 : 0.125)) : 0.000);
			dst[1] = lerp(dst[1], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.250 : 0.000);
			dst[21] = lerp(dst[21], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.750 : 0.000);
			dst[22] = lerp(dst[22], blendPix, (needBlend && doLineBlend) ? ((haveSteepLine) ? 1.000 : ((haveShallowLine) ? 0.250 : 0.125)) : 0.000);
			dst[23] = lerp(dst[23], blendPix, (needBlend) ? ((doLineBlend) ? ((!haveShallowLine && !haveSteepLine) ? 0.875 : 1.000) : 0.2306749731) : 0.000);
			dst[24] = lerp(dst[24], blendPix, (needBlend) ? ((doLineBlend) ? 1.000 : 0.8631434088) : 0.000);
			dst[9] = lerp(dst[9], blendPix, (needBlend) ? ((doLineBlend) ? ((!haveShallowLine && !haveSteepLine) ? 0.875 : 1.000) : 0.2306749731) : 0.000);
			dst[10] = lerp(dst[10], blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? 1.000 : ((haveSteepLine) ? 0.250 : 0.125)) : 0.000);
			dst[11] = lerp(dst[11], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.750 : 0.000);
			dst[12] = lerp(dst[12], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.250 : 0.000);
			dst[20] = lerp(dst[20], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.250 : 0.000);
			 

			dist_01_04 = DistYCbCr(src[5], src[8]);
			dist_03_08 = DistYCbCr(src[7], src[4]);
			haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v[0] != v[8]) && (v[1] != v[8]);
			haveSteepLine = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v[0] != v[4]) && (v[3] != v[4]);
			needBlend = (blendResult[0] != BLEND_NONE);
			doLineBlend = (blendResult[0] >= BLEND_DOMINANT ||
				!((blendResult[3] != BLEND_NONE && !IsPixEqual(src[0], src[8])) ||
				(blendResult[1] != BLEND_NONE && !IsPixEqual(src[0], src[4])) ||
					(IsPixEqual(src[8], src[7]) && IsPixEqual(src[7], src[6]) && IsPixEqual(src[6], src[5]) && IsPixEqual(src[5], src[4]) && !IsPixEqual(src[0], src[6]))));

			blendPix = (DistYCbCr(src[0], src[5]) <= DistYCbCr(src[0], src[7])) ? src[5] : src[7];
			dst[5] = lerp(dst[5], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.250 : 0.000);
			dst[6] = lerp(dst[6], blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 2.0 / 3.0 : 0.750) : ((haveSteepLine) ? 0.750 : 0.125)) : 0.000);
			dst[7] = lerp(dst[7], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.250 : 0.000);
			dst[17] = lerp(dst[17], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.750 : 0.000);
			dst[18] = lerp(dst[18], blendPix, (needBlend && doLineBlend) ? ((haveSteepLine) ? 1.000 : ((haveShallowLine) ? 0.250 : 0.125)) : 0.000);
			dst[19] = lerp(dst[19], blendPix, (needBlend) ? ((doLineBlend) ? ((!haveShallowLine && !haveSteepLine) ? 0.875 : 1.000) : 0.2306749731) : 0.000);
			dst[20] = lerp(dst[20], blendPix, (needBlend) ? ((doLineBlend) ? 1.000 : 0.8631434088) : 0.000);
			dst[21] = lerp(dst[21], blendPix, (needBlend) ? ((doLineBlend) ? ((!haveShallowLine && !haveSteepLine) ? 0.875 : 1.000) : 0.2306749731) : 0.000);
			dst[22] = lerp(dst[22], blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? 1.000 : ((haveSteepLine) ? 0.250 : 0.125)) : 0.000);
			dst[23] = lerp(dst[23], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.750 : 0.000);
			dst[24] = lerp(dst[24], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.250 : 0.000);
			dst[16] = lerp(dst[16], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.250 : 0.000);


			dist_01_04 = DistYCbCr(src[3], src[6]);
			dist_03_08 = DistYCbCr(src[5], src[2]);
			haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v[0] != v[6]) && (v[7] != v[6]);
			haveSteepLine = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v[0] != v[2]) && (v[1] != v[2]);
			needBlend = (blendResult[3] != BLEND_NONE);
			doLineBlend = (blendResult[3] >= BLEND_DOMINANT ||
				!((blendResult[2] != BLEND_NONE && !IsPixEqual(src[0], src[6])) ||
				(blendResult[0] != BLEND_NONE && !IsPixEqual(src[0], src[2])) ||
					(IsPixEqual(src[6], src[5]) && IsPixEqual(src[5], src[4]) && IsPixEqual(src[4], src[3]) && IsPixEqual(src[3], src[2]) && !IsPixEqual(src[0], src[4]))));

			blendPix = (DistYCbCr(src[0], src[3]) <= DistYCbCr(src[0], src[5])) ? src[3] : src[5];
			dst[3] = lerp(dst[3], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.250 : 0.000);
			dst[4] = lerp(dst[4], blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 2.0 / 3.0 : 0.750) : ((haveSteepLine) ? 0.750 : 0.125)) : 0.000);
			dst[5] = lerp(dst[5], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.250 : 0.000);
			dst[13] = lerp(dst[13], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.750 : 0.000);
			dst[14] = lerp(dst[14], blendPix, (needBlend && doLineBlend) ? ((haveSteepLine) ? 1.000 : ((haveShallowLine) ? 0.250 : 0.125)) : 0.000);
			dst[15] = lerp(dst[15], blendPix, (needBlend) ? ((doLineBlend) ? ((!haveShallowLine && !haveSteepLine) ? 0.875 : 1.000) : 0.2306749731) : 0.000);
			dst[16] = lerp(dst[16], blendPix, (needBlend) ? ((doLineBlend) ? 1.000 : 0.8631434088) : 0.000);
			dst[17] = lerp(dst[17], blendPix, (needBlend) ? ((doLineBlend) ? ((!haveShallowLine && !haveSteepLine) ? 0.875 : 1.000) : 0.2306749731) : 0.000);
			dst[18] = lerp(dst[18], blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? 1.000 : ((haveSteepLine) ? 0.250 : 0.125)) : 0.000);
			dst[19] = lerp(dst[19], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.750 : 0.000);
			dst[20] = lerp(dst[20], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.250 : 0.000);
			dst[12] = lerp(dst[12], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.250 : 0.000);
		}

		float3 res = lerp(lerp(dst[20], lerp(lerp(dst[21], dst[22], step(0.40, f.x)), lerp(dst[23], dst[24], step(0.80, f.x)), step(0.60, f.x)), step(0.20, f.x)),
			lerp(lerp(lerp(dst[19], lerp(lerp(dst[6], dst[7], step(0.40, f.x)), lerp(dst[8], dst[9], step(0.80, f.x)), step(0.60, f.x)), step(0.20, f.x)),
				lerp(dst[18], lerp(lerp(dst[5], dst[0], step(0.40, f.x)), lerp(dst[1], dst[10], step(0.80, f.x)), step(0.60, f.x)), step(0.20, f.x)), step(0.40, f.y)),
				lerp(lerp(dst[17], lerp(lerp(dst[4], dst[3], step(0.40, f.x)), lerp(dst[2], dst[11], step(0.80, f.x)), step(0.60, f.x)), step(0.20, f.x)),
					lerp(dst[16], lerp(lerp(dst[15], dst[14], step(0.40, f.x)), lerp(dst[13], dst[12], step(0.80, f.x)), step(0.60, f.x)), step(0.20, f.x)), step(0.80, f.y)),
				step(0.60, f.y)),
			step(0.20, f.y));

		return float4(res, 1.0);
	}


		ENDCG
	}
	}
		FallBack "Diffuse"
}