// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/XBR-LV2-Fast"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1) //You should set this field in Unity scripting, material.SetColor
		_MainTex("Albedo (RGB)", 2D) = "white" {}
	decal("decal (RGB)", 2D) = "white" {} //you should also set this in scripting with material.SetTexture ("decal", yourDecalTexture)
	texture_size("texture_size", Vector) = (256,224,0,0)
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
		uniform float XBR_SCALE;
	uniform float XBR_Y_WEIGHT;
	uniform float XBR_EQ_THRESHOLD;
	uniform float XBR_LV2_COEFFICIENT;
#else
#define XBR_SCALE 3.0
#define XBR_Y_WEIGHT 48.0
#define XBR_EQ_THRESHOLD 15.0
#define XBR_LV2_COEFFICIENT 2.0
#endif

#include "compat_includes.inc"
		/*
		Hyllian's xBR-lv2-lq Shader

		Copyright (C) 2011/2015 Hyllian/Jararaca - sergiogdb@gmail.com

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


		Incorporates some of the ideas from SABR shader. Thanks to Joshua Street.
		*/
		/*
		Leonardo da Luz Pinto's xBR-lv2 shader Adaptation to Unity ShaderLab

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

	float2 texture_size; // set from outside the shader ( THIS NOTE WAS MADE BY SONOSHEE)

	const static float coef = 2.0;

	const static float y_weight = 48.0;
	const static float u_weight = 7.0;
	const static float v_weight = 6.0;
	const static float3x3 yuv = float3x3(0.299, 0.587, 0.114, -0.169, -0.331, 0.499, 0.499, -0.418, -0.0813);
	const static float3x3 yuv_weighted = float3x3(y_weight*yuv[0], u_weight*yuv[1], v_weight*yuv[2]);
	const static float4 delta = float4(0.5, 0.5, 0.5, 0.5);
	const static float sharpness = 0.65;



	const static float4 Ao = float4(1.0, -1.0, -1.0, 1.0);
	const static float4 Bo = float4(1.0, 1.0, -1.0, -1.0);
	const static float4 Co = float4(1.5, 0.5, -0.5, 0.5);
	const static float4 Ax = float4(1.0, -1.0, -1.0, 1.0);
	const static float4 Bx = float4(0.5, 2.0, -0.5, -2.0);
	const static float4 Cx = float4(1.0, 1.0, -0.5, 0.0);
	const static float4 Ay = float4(1.0, -1.0, -1.0, 1.0);
	const static float4 By = float4(2.0, 0.5, -2.0, -0.5);
	const static float4 Cy = float4(2.0, 0.0, -1.0, 0.5);
	const static float4 Ci = float4(0.25, 0.25, 0.25, 0.25);

	const static float3 Y = float3(0.2126, 0.7152, 0.0722);


	float4 df(float4 A, float4 B)
	{
		return float4(abs(A - B));
	}


	bool4 eq(float4 A, float4 B)
	{
		return (df(A, B) < XBR_EQ_THRESHOLD);
	}

	bool4 eq2(float4 A, float4 B)
	{
		return (df(A, B) < float4(2.0, 2.0, 2.0, 2.0));
	}
	float c_df(float3 c1, float3 c2)
	{
		float3 df = abs(c1 - c2);
		return df.r + df.g + df.b;
	}


	float4 weighted_distance(float4 a, float4 b, float4 c, float4 d, float4 e, float4 f, float4 g, float4 h)
	{
		return (df(a, b) + df(a, c) + df(d, e) + df(d, f) + 4.0*df(g, h));
	}

	struct out_vertex
	{
		float4 position : POSITION;
		float4 color : COLOR;
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
		OUT.color = _Color;

		float2 ps = float2(1.0 / texture_size.x, 1.0 / texture_size.y);
		float dx = ps.x;
		float dy = ps.y;

		// A1 B1 C1
		// A0 A B C C4
		// D0 D E F F4
		// G0 G H I I4
		// G5 H5 I5

		OUT.texCoord = v.texcoord + float2(0.0000001, dy);
		OUT.t1 = OUT.texCoord.xxxy + float4(-dx, 0, dx, -2.0*dy); // A1 B1 C1
		OUT.t2 = OUT.texCoord.xxxy + float4(-dx, 0, dx, -dy); // A B C
		OUT.t3 = OUT.texCoord.xxxy + float4(-dx, 0, dx, 0); // D E F
		OUT.t4 = OUT.texCoord.xxxy + float4(-dx, 0, dx, dy); // G H I
		OUT.t5 = OUT.texCoord.xxxy + float4(-dx, 0, dx, 2.0*dy); // G5 H5 I5
		OUT.t6 = OUT.texCoord.xyyy + float4(-2.0*dx, -dy, 0, dy); // A0 D0 G0
		OUT.t7 = OUT.texCoord.xyyy + float4(2.0*dx, -dy, 0, dy); // C4 F4 I4

		return OUT;
	}

	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{
		bool4 edri, edr, edr_left, edr_up, px; // px = pixel, edr = edge detection rule
	bool4 interp_restriction_lv0, interp_restriction_lv1, interp_restriction_lv2_left, interp_restriction_lv2_up;
	float4 fx, fx_left, fx_up; // inequations of straight lines.

	float4 delta = float4(1.0 / XBR_SCALE, 1.0 / XBR_SCALE, 1.0 / XBR_SCALE, 1.0 / XBR_SCALE);
	float4 deltaL = float4(0.5 / XBR_SCALE, 1.0 / XBR_SCALE, 0.5 / XBR_SCALE, 1.0 / XBR_SCALE);
	float4 deltaU = deltaL.yxwz;

	float2 fp = frac(VAR.texCoord*texture_size);

	float3 A = COMPAT_SamplePoint(decal, VAR.t1.xw).rgb;
	float3 B = COMPAT_SamplePoint(decal, VAR.t1.yw).rgb;
	float3 C = COMPAT_SamplePoint(decal, VAR.t1.zw).rgb;

	float3 D = COMPAT_SamplePoint(decal, VAR.t2.xw).rgb;
	float3 E = COMPAT_SamplePoint(decal, VAR.t2.yw).rgb;
	float3 F = COMPAT_SamplePoint(decal, VAR.t2.zw).rgb;

	float3 G = COMPAT_SamplePoint(decal, VAR.t3.xw).rgb;
	float3 H = COMPAT_SamplePoint(decal, VAR.t3.yw).rgb;
	float3 I = COMPAT_SamplePoint(decal, VAR.t3.zw).rgb;


	float4 b = mul(float4x3(B, D, H, F), XBR_Y_WEIGHT*Y);
	float4 c = mul(float4x3(C, A, G, I), XBR_Y_WEIGHT*Y);
	float4 e = mul(float4x3(E, E, E, E), XBR_Y_WEIGHT*Y);
	float4 a = c.yzwx;
	float4 d = b.yzwx;
	float4 f = b.wxyz;
	float4 g = c.zwxy;
	float4 h = b.zwxy;
	float4 i = c.wxyz;

	// These inequations define the line below which interpolation occurs.
	fx = (Ao*fp.y + Bo*fp.x);
	fx_left = (Ax*fp.y + Bx*fp.x);
	fx_up = (Ay*fp.y + By*fp.x);

	interp_restriction_lv1 = interp_restriction_lv0 = ((e != f) && (e != h));

#ifndef CORNER_A
	interp_restriction_lv1 = (interp_restriction_lv0 && (!eq(f,b) && !eq(f,c) || !eq(h,d) && !eq(h,g) || eq(e,g) || eq(e,c)));
#endif

	interp_restriction_lv2_left = ((e != g) && (d != g));
	interp_restriction_lv2_up = ((e != c) && (b != c));

	float4 fx45i = saturate((fx + delta - Co - Ci) / (2 * delta));
	float4 fx45 = saturate((fx + delta - Co) / (2 * delta));
	float4 fx30 = saturate((fx_left + deltaL - Cx) / (2 * deltaL));
	float4 fx60 = saturate((fx_up + deltaU - Cy) / (2 * deltaU));

	float4 wd1 = weighted_distance(d, b, g, e, e, c, h, f);
	float4 wd2 = weighted_distance(a, e, b, f, d, h, e, i);

	edri = (wd1 <= wd2) && interp_restriction_lv0;
	edr = (wd1 <  wd2) && interp_restriction_lv1;
	edr_left = ((XBR_LV2_COEFFICIENT*df(f,g)) <= df(h,c)) && interp_restriction_lv2_left && edr;
	edr_up = (df(f,g) >= (XBR_LV2_COEFFICIENT*df(h,c))) && interp_restriction_lv2_up && edr;

	fx45 = edr*fx45;
	fx30 = edr_left*fx30;
	fx60 = edr_up*fx60;
	fx45i = edri*fx45i;

	px = (df(e,f) <= df(e,h));

#ifdef SMOOTH_TIPS
	float4 maximos = max(max(fx30, fx60), max(fx45, fx45i));
#else
	float4 maximos = max(max(fx30, fx60), fx45);
#endif

	float3 res1 = E;
	res1 = lerp(res1, lerp(H, F, px.x), maximos.x);
	res1 = lerp(res1, lerp(B, D, px.z), maximos.z);

	float3 res2 = E;
	res2 = lerp(res2, lerp(F, B, px.y), maximos.y);
	res2 = lerp(res2, lerp(D, H, px.w), maximos.w);

	float3 res = lerp(res1, res2, step(c_df(E, res1), c_df(E, res2)));

	return float4(res, 1.0);
	}

		ENDCG
	}
	}
		FallBack "Diffuse"
}