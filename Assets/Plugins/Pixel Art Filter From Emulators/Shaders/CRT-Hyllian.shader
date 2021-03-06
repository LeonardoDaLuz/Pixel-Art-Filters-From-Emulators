// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/CRT Hyllian"
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
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
		// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices ( THIS NOTE WAS MADE BY UNITY)
//#pragma exclude_renderers gles // NOTE : this was added automatically by Unity each time I compile the shader ( THIS NOTE WAS MADE BY SONOSHEE)
#include "UnityCG.cginc"

#pragma vertex main_vertex
#pragma fragment main_fragment
#pragma target 3.0
//#pragma parameter PHOSPHOR "CRT - Phosphor ON/OFF" 1.0 0.0 1.0 1.0
//#pragma parameter VSCANLINES "CRT - Scanlines Direction" 0.0 0.0 1.0 1.0
//#pragma parameter InputGamma "CRT - Input gamma" 2.5 0.0 5.0 0.1
//#pragma parameter OutputGamma "CRT - Output Gamma" 2.2 0.0 5.0 0.1
//#pragma parameter SHARPNESS "CRT - Sharpness Hack" 1.0 1.0 5.0 1.0
//#pragma parameter COLOR_BOOST "CRT - Color Boost" 1.5 1.0 2.0 0.05
//#pragma parameter RED_BOOST "CRT - Red Boost" 1.0 1.0 2.0 0.01
//#pragma parameter GREEN_BOOST "CRT - Green Boost" 1.0 1.0 2.0 0.01
//#pragma parameter BLUE_BOOST "CRT - Blue Boost" 1.0 1.0 2.0 0.01
//#pragma parameter SCANLINES_STRENGTH "CRT - Scanline Strength" 0.50 0.0 1.0 0.02
//#pragma parameter BEAM_MIN_WIDTH "CRT - Min Beam Width" 0.86 0.0 1.0 0.02
//#pragma parameter BEAM_MAX_WIDTH "CRT - Max Beam Width" 1.0 0.0 1.0 0.02
//#pragma parameter CRT_ANTI_RINGING "CRT - Anti-Ringing" 0.8 0.0 1.0 0.1
//#ifdef PARAMETER_UNIFORM
		uniform float PHOSPHOR;
	uniform float VSCANLINES;
	uniform float InputGamma;
	uniform float OutputGamma;
	uniform float SHARPNESS;
	uniform float COLOR_BOOST;
	uniform float RED_BOOST;
	uniform float GREEN_BOOST;
	uniform float BLUE_BOOST;
	uniform float SCANLINES_STRENGTH;
	uniform float BEAM_MIN_WIDTH;
	uniform float BEAM_MAX_WIDTH;
	uniform float CRT_ANTI_RINGING;
//#else
//#define PHOSPHOR 1.0
//#define VSCANLINES 0.0
//#define InputGamma 2.5
//#define OutputGamma 2.2
//#define SHARPNESS 1.0
//#define COLOR_BOOST 1.5
//#define RED_BOOST 1.0
//#define GREEN_BOOST 1.0
//#define BLUE_BOOST 1.0
//#define SCANLINES_STRENGTH 0.50
//#define BEAM_MIN_WIDTH 0.86
//#define BEAM_MAX_WIDTH 1.0
//#define CRT_ANTI_RINGING 0.8 
//#endif
#include "compat_includes.inc"
		/*
		Hyllian's CRT Shader

		Copyright (C) 2011-2015 Hyllian - sergiogdb@gmail.com

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

		uniform half4 _Color;
	uniform sampler2D decal : TEXUNIT0;


#define GAMMA_IN(color)     pow(color, float3(InputGamma, InputGamma, InputGamma))
#define GAMMA_OUT(color)    pow(color, float3(1.0 / OutputGamma, 1.0 / OutputGamma, 1.0 / OutputGamma))

	// Horizontal cubic filter.

	// Some known filters use these values:

	//    B = 0.0, C = 0.0  =>  Hermite cubic filter.
	//    B = 1.0, C = 0.0  =>  Cubic B-Spline filter.
	//    B = 0.0, C = 0.5  =>  Catmull-Rom Spline filter. This is the default used in this shader.
	//    B = C = 1.0/3.0   =>  Mitchell-Netravali cubic filter.
	//    B = 0.3782, C = 0.3109  =>  Robidoux filter.
	//    B = 0.2620, C = 0.3690  =>  Robidoux Sharp filter.
	//    B = 0.36, C = 0.28  =>  My best config for ringing elimination in pixel art (Hyllian).


	// For more info, see: http://www.imagemagick.org/Usage/img_diagrams/cubic_survey.gif

	// Change these params to configure the horizontal filter.
	const static float  B = 0.0;
	const static float  C = 0.5;

	const static float4x4 invX = float4x4((-B - 6.0*C) / 6.0, (3.0*B + 12.0*C) / 6.0, (-3.0*B - 6.0*C) / 6.0, B / 6.0,
		(12.0 - 9.0*B - 6.0*C) / 6.0, (-18.0 + 12.0*B + 6.0*C) / 6.0, 0.0, (6.0 - 2.0*B) / 6.0,
		-(12.0 - 9.0*B - 6.0*C) / 6.0, (18.0 - 15.0*B - 12.0*C) / 6.0, (3.0*B + 6.0*C) / 6.0, B / 6.0,
		(B + 6.0*C) / 6.0, -C, 0.0, 0.0);


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
		return OUT;




	}


	float4 crt_hyllian(float2 texture_size, float2 video_size, float2 output_size, float2 texCoord, COMPAT_Texture2D(s_p))
	{
		float3 color;

		float2 TextureSize = float2(SHARPNESS*texture_size.x, texture_size.y);

		float2 dx = lerp(float2(1.0 / TextureSize.x, 0.0), float2(0.0, 1.0 / TextureSize.y), VSCANLINES);
		float2 dy = lerp(float2(0.0, 1.0 / TextureSize.y), float2(1.0 / TextureSize.x, 0.0), VSCANLINES);

		float2 pix_coord = texCoord*TextureSize + float2(-0.5, 0.5);

		float2 tc = lerp((floor(pix_coord) + float2(0.5, 0.5)) / TextureSize, (floor(pix_coord) + float2(1.0, -0.5)) / TextureSize, VSCANLINES);

		float2 fp = lerp(frac(pix_coord), frac(pix_coord.yx), VSCANLINES);

		float3 c00 = GAMMA_IN(COMPAT_SamplePoint(s_p, tc - dx - dy).xyz);
		float3 c01 = GAMMA_IN(COMPAT_SamplePoint(s_p, tc - dy).xyz);
		float3 c02 = GAMMA_IN(COMPAT_SamplePoint(s_p, tc + dx - dy).xyz);
		float3 c03 = GAMMA_IN(COMPAT_SamplePoint(s_p, tc + 2.0*dx - dy).xyz);
		float3 c10 = GAMMA_IN(COMPAT_SamplePoint(s_p, tc - dx).xyz);
		float3 c11 = GAMMA_IN(COMPAT_SamplePoint(s_p, tc).xyz);
		float3 c12 = GAMMA_IN(COMPAT_SamplePoint(s_p, tc + dx).xyz);
		float3 c13 = GAMMA_IN(COMPAT_SamplePoint(s_p, tc + 2.0*dx).xyz);

		//  Get min/max samples
		float3 min_sample = min(min(c01, c11), min(c02, c12));
		float3 max_sample = max(max(c01, c11), max(c02, c12));

		float4x3 color_matrix0 = float4x3(c00, c01, c02, c03);
		float4x3 color_matrix1 = float4x3(c10, c11, c12, c13);

		float4 invX_Px = mul(invX, float4(fp.x*fp.x*fp.x, fp.x*fp.x, fp.x, 1.0));
		float3 color0 = mul(invX_Px, color_matrix0);
		float3 color1 = mul(invX_Px, color_matrix1);

		// Anti-ringing
		float3 aux = color0;
		color0 = clamp(color0, min_sample, max_sample);
		color0 = lerp(aux, color0, CRT_ANTI_RINGING);
		aux = color1;
		color1 = clamp(color1, min_sample, max_sample);
		color1 = lerp(aux, color1, CRT_ANTI_RINGING);

		float pos0 = fp.y;
		float pos1 = 1 - fp.y;

		float3 lum0 = lerp(float3(BEAM_MIN_WIDTH, BEAM_MIN_WIDTH, BEAM_MIN_WIDTH), float3(BEAM_MAX_WIDTH, BEAM_MAX_WIDTH, BEAM_MAX_WIDTH), color0);
		float3 lum1 = lerp(float3(BEAM_MIN_WIDTH, BEAM_MIN_WIDTH, BEAM_MIN_WIDTH), float3(BEAM_MAX_WIDTH, BEAM_MAX_WIDTH, BEAM_MAX_WIDTH), color1);

		float3 d0 = clamp(pos0 / (lum0 + 0.0000001), 0.0, 1.0);
		float3 d1 = clamp(pos1 / (lum1 + 0.0000001), 0.0, 1.0);

		d0 = exp(-10.0*SCANLINES_STRENGTH*d0*d0);
		d1 = exp(-10.0*SCANLINES_STRENGTH*d1*d1);

		color = clamp(color0*d0 + color1*d1, 0.0, 1.0);

		color *= COLOR_BOOST*float3(RED_BOOST, GREEN_BOOST, BLUE_BOOST);

		float mod_factor = lerp(texCoord.x * output_size.x * texture_size.x / video_size.x, texCoord.y * output_size.y * texture_size.y / video_size.y, VSCANLINES);

		float3 dotMaskWeights = lerp(
			float3(1.0, 0.7, 1.0),
			float3(0.7, 1.0, 0.7),
			floor(fmod(mod_factor, 2.0))
		);

		color.rgb *= lerp(float3(1.0, 1.0, 1.0), dotMaskWeights, PHOSPHOR);

		color = GAMMA_OUT(color);

		return float4(color, 1.0);
	}



	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{ 
		return crt_hyllian(texture_size, video_size, output_size, VAR.texcoord, decal);
	}


		ENDCG
	}
	}
		FallBack "Diffuse"
}