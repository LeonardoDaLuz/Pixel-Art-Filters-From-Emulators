// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/CRT Hyllian Glow"
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

#ifdef PARAMETER_UNIFORM
		uniform float SHARPNESS;
	uniform float RED_BOOST;
	uniform float GREEN_BOOST;
	uniform float SCANLINES_STRENGTH;
	uniform float BEAM_MIN_WIDTH;
	uniform float BEAM_MAX_WIDTH;
	uniform float COLOR_BOOST;
	uniform float CRT_TV_BLUE_TINT;
#else
#define SHARPNESS 2.0
#define RED_BOOST 1.0
#define GREEN_BOOST 1.0
#define SCANLINES_STRENGTH 0.72
#define BEAM_MIN_WIDTH 0.86
#define BEAM_MAX_WIDTH 1.0
#define COLOR_BOOST 1.4
#define CRT_TV_BLUE_TINT 1.0 
#endif

		// Uncomment to enable anti-ringing to horizontal filter.
		//#define ANTI_RINGING

		// Uncomment to increase the sharpness of the scanlines.
		//#define SHARPER

		// Comment next line if you don't desire the phosphor effect.
		//#define PHOSPHOR

		// Uncomment to enable adjustment of red and green saturation.
		//#define RED_GREEN_CONTROL

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

	const static float4x4 invX = float4x4((-B - 6.0*C) / 6.0,         (3.0*B + 12.0*C) / 6.0,     (-3.0*B - 6.0*C) / 6.0,             B / 6.0,
		(12.0 - 9.0*B - 6.0*C) / 6.0, (-18.0 + 12.0*B + 6.0*C) / 6.0,                      0.0, (6.0 - 2.0*B) / 6.0,
		-(12.0 - 9.0*B - 6.0*C) / 6.0, (18.0 - 15.0*B - 12.0*C) / 6.0,      (3.0*B + 6.0*C) / 6.0,             B / 6.0,

		(B + 6.0*C) / 6.0,                           -C,                      0.0,               0.0);


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
#ifdef SHARPER
		float2 TextureSize = float2(SHARPNESS*texture_size.x, texture_size.y);
#else
		float2 TextureSize = texture_size;
#endif

		float3 color;
		float2 dx = float2(1.0 / TextureSize.x, 0.0);
		float2 dy = float2(0.0, 1.0 / TextureSize.y);
		float2 pix_coord = VAR.texCoord*TextureSize + float2(-0.5,0.5);

		float2 tc = (floor(pix_coord) + float2(0.5,0.5)) / TextureSize;

		float2 fp = frac(pix_coord);

		float3 c00 = tex2D(decal, tc - dx - dy).xyz;
		float3 c01 = tex2D(decal, tc - dy).xyz;
		float3 c02 = tex2D(decal, tc + dx - dy).xyz;
		float3 c03 = tex2D(decal, tc + 2.0*dx - dy).xyz;
		float3 c10 = tex2D(decal, tc - dx).xyz;
		float3 c11 = tex2D(decal, tc).xyz;
		float3 c12 = tex2D(decal, tc + dx).xyz;
		float3 c13 = tex2D(decal, tc + 2.0*dx).xyz;

#ifdef ANTI_RINGING
		//  Get min/max samples
		float3 min_sample = min(min(c01,c11), min(c02,c12));
		float3 max_sample = max(max(c01,c11), max(c02,c12));
#endif

		float4x3 color_matrix0 = float4x3(c00, c01, c02, c03);
		float4x3 color_matrix1 = float4x3(c10, c11, c12, c13);

		float4 invX_Px = mul(invX, float4(fp.x*fp.x*fp.x, fp.x*fp.x, fp.x, 1.0));
		float3 color0 = mul(invX_Px, color_matrix0);
		float3 color1 = mul(invX_Px, color_matrix1);

		float pos0 = fp.y;
		float pos1 = 1 - fp.y;

		float3 lum0 = lerp(float3(BEAM_MIN_WIDTH,0,0), float3(BEAM_MAX_WIDTH,0,0), color0);
		float3 lum1 = lerp(float3(BEAM_MIN_WIDTH,0,0), float3(BEAM_MAX_WIDTH,0,0), color1);

		float3 d0 = clamp(pos0 / (lum0 + 0.0000001), 0.0, 1.0);
		float3 d1 = clamp(pos1 / (lum1 + 0.0000001), 0.0, 1.0);

		d0 = exp(-10.0*SCANLINES_STRENGTH*d0*d0);
		d1 = exp(-10.0*SCANLINES_STRENGTH*d1*d1);

		color = clamp(color0*d0 + color1*d1, 0.0, 1.0);

#ifdef PHOSPHOR
		float mod_factor = VAR.texCoord.x * IN.output_size.x * IN.texture_size.x / IN.video_size.x;

		float3 dotMaskWeights = lerp(
			float3(1.0, 0.7, 1.0),
			float3(0.7, 1.0, 0.7),
			floor(fmod(mod_factor, 2.0))
		);

		color.rgb *= dotMaskWeights;
#endif                   

		color *= COLOR_BOOST;

#ifdef RED_GREEN_CONTROL
		color.rgb *= float3(RED_BOOST, GREEN_BOOST, CRT_TV_BLUE_TINT);
#else
		color.b *= CRT_TV_BLUE_TINT;
#endif

#ifdef ANTI_RINGING
		// Anti-ringing
		color = clamp(color, min_sample, max_sample);
#endif

		return float4(color, 1.0);
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
	uniform sampler2D decal : TEXUNIT1;
	sampler2D _BackgroundTexture;

	float2 texture_size; // set from outside the shader ( THIS NOTE WAS MADE BY SONOSHEE)

#ifdef PARAMETER_UNIFORM
	uniform float BLOOM_STRENGTH;
	uniform float SOURCE_BOOST;
#else
#define BLOOM_STRENGTH 0.9
#define SOURCE_BOOST 2.0
#endif



	struct out_vertex
	{
		float4 position : POSITION;
		float4 texCoord : TEXCOORD0;
		float2 prev : TEXCOORD1;

	};


	//VERTEX_SHADER
	out_vertex main_vertex(appdata_base v)
	{
		out_vertex OUT;

		OUT.position = UnityObjectToClipPos(v.vertex);
		OUT.texCoord = ComputeGrabScreenPos(OUT.position);
		OUT.prev = v.texcoord;

		return OUT;
	}
#define INV_OUTPUT_GAMMA (1.0 / 2.2)

	//FRAGMENT SHADER 
	half4 main_fragment(out_vertex VAR) : COLOR
	{ 
		return float4(tex2D(decal, VAR.prev).rgba );
//#if BLOOM_ONLY
//		float3 source = BLOOM_STRENGTH * tex2D(_BackgroundTexture, vert.tex).rgb;
//#else
//		float3 source = SOURCE_BOOST * tex2D(_BackgroundTexture, VAR.texCoord).rgb;
//		float3 bloom = tex2D(_BackgroundTexture, VAR.texCoord).rgb;
//		source += BLOOM_STRENGTH * bloom;
//#endif
//		return float4(pow(saturate(source), INV_OUTPUT_GAMMA), 1.0);
	}


		ENDCG
	}
	}
		FallBack "Diffuse"
}