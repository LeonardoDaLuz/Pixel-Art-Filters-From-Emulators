// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/CRT Aperture"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1) //You should set this field in Unity scripting, material.SetColor
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
		uniform float SHARPNESS_IMAGE;
	uniform float SHARPNESS_EDGES;
	uniform float GLOW_WIDTH;
	uniform float GLOW_HEIGHT;
	uniform float GLOW_HALATION;
	uniform float GLOW_DIFFUSION;
	uniform float MASK_COLORS;
	uniform float MASK_STRENGTH;
	uniform float MASK_SIZE;
	uniform float SCANLINE_SIZE_MIN;
	uniform float SCANLINE_SIZE_MAX;
	uniform float GAMMA_INPUT;
	uniform float GAMMA_OUTPUT;
	uniform float BRIGHTNESS;
#else
#define SHARPNESS_IMAGE 1.0
#define SHARPNESS_EDGES 3.0
#define GLOW_WIDTH 0.5
#define GLOW_HEIGHT 0.5
#define GLOW_HALATION 0.1
#define GLOW_DIFFUSION 0.05
#define MASK_COLORS 2.0
#define MASK_STRENGTH 0.3
#define MASK_SIZE 1.0
#define SCANLINE_SIZE_MIN 0.5
#define SCANLINE_SIZE_MAX 1.5
#define GAMMA_INPUT 2.4
#define GAMMA_OUTPUT 2.4
#define BRIGHTNESS 1.5
#endif
#include "compat_includes.inc"

		/*
		CRT Shader by EasyMode
		License: GPL
		*/
		/*
		Leonardo da Luz Pinto's CRT shader Adaptation to Unity ShaderLab

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

#define FIX(c) max(abs(c), 1e-5)
#define PI 3.141592653589
#define TEX2D(c) pow(COMPAT_SamplePoint(tex, c).rgb, GAMMA_INPUT)
#define mod(x,y) (x - y * trunc(x/y))


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
		float4 color : COLOR;
		float2 texCoord : TEXCOORD0;

	};
	float3x3 get_color_matrix(COMPAT_Texture2D(tex), float2 co, float2 dx)
	{
		return float3x3(TEX2D(co - dx), TEX2D(co), TEX2D(co + dx));
	}

	float3 blur(float3x3 m, float dist, float rad)
	{
		float3 x = float3(dist - 1.0, dist, dist + 1.0) / rad;
		float3 w = exp2(x * x * -1.0);

		return (m[0] * w.x + m[1] * w.y + m[2] * w.z) / (w.x + w.y + w.z);
	}

	float3 filter_gaussian(COMPAT_Texture2D(tex), float2 co, float2 tex_size)
	{
		float2 dx = float2(1.0 / tex_size.x, 0.0);
		float2 dy = float2(0.0, 1.0 / tex_size.y);
		float2 pix_co = co * tex_size;
		float2 tex_co = (floor(pix_co) + 0.5) / tex_size;
		float2 dist = (frac(pix_co) - 0.5) * -1.0;

		float3x3 line0 = get_color_matrix(tex, tex_co - dy, dx);
		float3x3 line1 = get_color_matrix(tex, tex_co, dx);
		float3x3 line2 = get_color_matrix(tex, tex_co + dy, dx);
		float3x3 column = float3x3(blur(line0, dist.x, GLOW_WIDTH),
			blur(line1, dist.x, GLOW_WIDTH),
			blur(line2, dist.x, GLOW_WIDTH));

		return blur(column, dist.y, GLOW_HEIGHT);
	}

	float3 filter_lanczos(COMPAT_Texture2D(tex), float2 co, float2 tex_size, float sharp)
	{
		tex_size.x *= sharp;

		float2 dx = float2(1.0 / tex_size.x, 0.0);
		float2 pix_co = co * tex_size - float2(0.5, 0.0);
		float2 tex_co = (floor(pix_co) + float2(0.5, 0.0)) / tex_size;
		float2 dist = frac(pix_co);
		float4 coef = PI * float4(dist.x + 1.0, dist.x, dist.x - 1.0, dist.x - 2.0);

		coef = FIX(coef);
		coef = 2.0 * sin(coef) * sin(coef / 2.0) / (coef * coef);
		coef /= dot(coef, float4(1.0, 1.0, 1.0, 1.0));

		float4 col1 = float4(TEX2D(tex_co), 1.0);
		float4 col2 = float4(TEX2D(tex_co + dx), 1.0);

		return mul(coef, float4x4(col1, col1, col2, col2)).rgb;
	}

	float3 get_scanline_weight(float x, float3 col)
	{
		float3 beam = lerp(float3(SCANLINE_SIZE_MIN, SCANLINE_SIZE_MIN, SCANLINE_SIZE_MIN), float3(SCANLINE_SIZE_MAX, SCANLINE_SIZE_MAX, SCANLINE_SIZE_MAX), col);
		float3 x_mul = 2.0 / beam;
		float3 x_offset = x_mul * 0.5;

		return smoothstep(0.0, 1.0, 1.0 - abs(x * x_mul - x_offset)) * x_offset;
	}

	float3 get_mask_weight(float x, float2 texture_size, float2 video_size, float2 output_size)
	{
		float i = mod(floor(x * output_size.x * texture_size.x / (video_size.x * MASK_SIZE)), MASK_COLORS);

		if (i == 0.0) return lerp(float3(1.0, 0.0, 1.0), float3(1.0, 0.0, 0.0), MASK_COLORS - 2.0);
		else if (i == 1.0) return float3(0.0, 1.0, 0.0);
		else return float3(0.0, 0.0, 1.0);
	}
	float4 crt_aperture(COMPAT_Texture2D(tex), float2 co)
	{
		float3 col_glow = filter_gaussian(tex, co, texture_size);
		float3 col_soft = filter_lanczos(tex, co, texture_size, SHARPNESS_IMAGE);
		float3 col_sharp = filter_lanczos(tex, co, texture_size, SHARPNESS_EDGES);
		float3 col = sqrt(col_sharp * col_soft);

		col *= get_scanline_weight(frac(co.y * texture_size.y), col_soft);
		col_glow = saturate(col_glow - col);
		col += col_glow * col_glow * GLOW_HALATION;
		col = lerp(col, col * get_mask_weight(co.x, texture_size, video_size, output_size) * MASK_COLORS, MASK_STRENGTH);
		col += col_glow * GLOW_DIFFUSION;
		col = pow(col * BRIGHTNESS, 1.0 / GAMMA_OUTPUT);

		return float4(col, 1.0);
	}

	//VERTEX_SHADER
	out_vertex main_vertex(appdata_base v)
	{
		out_vertex OUT;

		OUT.position = UnityObjectToClipPos(v.vertex);
		OUT.color = _Color;

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
		return crt_aperture(decal, VAR.texCoord);
	}


		ENDCG
	}
	}
		FallBack "Diffuse"
}