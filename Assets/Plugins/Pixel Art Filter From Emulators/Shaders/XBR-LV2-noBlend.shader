// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/XBR-LV2-NoBlend"
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

#include "compat_includes.inc"
		/*
		Hyllian's xBR-lv2-noblend Shader

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
		Leonardo da Luz Pinto's xBR-lv2-noblend shader Adaptation to Unity ShaderLab

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

#ifdef PARAMETER_UNIFORM
		uniform float XBR_EQ_THRESHOLD;
	uniform float XBR_LV2_COEFFICIENT;
#else
#define XBR_EQ_THRESHOLD 0.6
#define XBR_LV2_COEFFICIENT 2.0
#endif
#define CORNER_A
		//#define CORNER_B
		//#define CORNER_C
		//#define CORNER_D


		uniform COMPAT_Texture2D(decal) : TEXUNIT0;

	uniform half4 _Color;


	const static float3 Y = float3(0.2126, 0.7152, 0.0722);
	float2 texture_size; // set from outside the shader ( THIS NOTE WAS MADE BY SONOSHEE)
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


	float4 df(float4 A, float4 B)
	{
		return float4(abs(A - B));
	}

	float c_df(float3 c1, float3 c2) {
		float3 df = abs(c1 - c2);
		return df.r + df.g + df.b;
	}


	bool4 eq(float4 A, float4 B)
	{
		return (df(A, B) < float4(XBR_EQ_THRESHOLD, XBR_EQ_THRESHOLD, XBR_EQ_THRESHOLD, XBR_EQ_THRESHOLD));
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

		// This line fix a bug in ATI cards. ( THIS NOTE WAS MADE BY XBR AUTHOR)
		//float2 texCoord = texCoord1 + float2(0.0000001, 0.0000001);

		OUT.texCoord = v.texcoord + +float2(0.0000001, 0.0000001);
		OUT.t1 = v.texcoord.xxxy + float4(-dx, 0, dx, -2.0*dy); // A1 B1 C1
		OUT.t2 = v.texcoord.xxxy + float4(-dx, 0, dx, -dy); // A B C
		OUT.t3 = v.texcoord.xxxy + float4(-dx, 0, dx, 0); // D E F
		OUT.t4 = v.texcoord.xxxy + float4(-dx, 0, dx, dy); // G H I
		OUT.t5 = v.texcoord.xxxy + float4(-dx, 0, dx, 2.0*dy); // G5 H5 I5
		OUT.t6 = v.texcoord.xyyy + float4(-2.0*dx, -dy, 0, dy); // A0 D0 G0
		OUT.t7 = v.texcoord.xyyy + float4(2.0*dx, -dy, 0, dy); // C4 F4 I4
		return OUT;
	}





	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{

		bool4 edri, edr, edr_left, edr_up, px; // px = pixel, edr = edge detection rule
	bool4 interp_restriction_lv1, interp_restriction_lv2_left, interp_restriction_lv2_up;
	bool4 nc; // new_color
	bool4 fx, fx_left, fx_up; // inequations of straight lines.

	float2 fp = frac(VAR.texCoord*texture_size);

	float3 A1 = tex2D(decal, VAR.t1.xw).rgb;
	float3 B1 = tex2D(decal, VAR.t1.yw).rgb;
	float3 C1 = tex2D(decal, VAR.t1.zw).rgb;

	float3 A = tex2D(decal, VAR.t2.xw).rgb;
	float3 B = tex2D(decal, VAR.t2.yw).rgb;
	float3 C = tex2D(decal, VAR.t2.zw).rgb;

	float3 D = tex2D(decal, VAR.t3.xw).rgb;
	float3 E = tex2D(decal, VAR.t3.yw).rgb;
	float3 F = tex2D(decal, VAR.t3.zw).rgb;

	float3 G = tex2D(decal, VAR.t4.xw).rgb;
	float3 H = tex2D(decal, VAR.t4.yw).rgb;
	float3 I = tex2D(decal, VAR.t4.zw).rgb;

	float3 G5 = tex2D(decal, VAR.t5.xw).rgb;
	float3 H5 = tex2D(decal, VAR.t5.yw).rgb;
	float3 I5 = tex2D(decal, VAR.t5.zw).rgb;

	float3 A0 = tex2D(decal, VAR.t6.xy).rgb;
	float3 D0 = tex2D(decal, VAR.t6.xz).rgb;
	float3 G0 = tex2D(decal, VAR.t6.xw).rgb;

	float3 C4 = tex2D(decal, VAR.t7.xy).rgb;
	float3 F4 = tex2D(decal, VAR.t7.xz).rgb;
	float3 I4 = tex2D(decal, VAR.t7.xw).rgb;

	float4 b = mul(float4x3(B, D, H, F), Y);
	float4 c = mul(float4x3(C, A, G, I), Y);
	float4 e = mul(float4x3(E, E, E, E), Y);
	float4 d = b.yzwx;
	float4 f = b.wxyz;
	float4 g = c.zwxy;
	float4 h = b.zwxy;
	float4 i = c.wxyz;

	float4 i4 = mul(float4x3(I4, C1, A0, G5), Y);
	float4 i5 = mul(float4x3(I5, C4, A1, G0), Y);
	float4 h5 = mul(float4x3(H5, F4, B1, D0), Y);
	float4 f4 = h5.yzwx;

	float4 Ao = float4(1.0, -1.0, -1.0, 1.0);
	float4 Bo = float4(1.0,  1.0, -1.0,-1.0);
	float4 Co = float4(1.5,  0.5, -0.5, 0.5);
	float4 Ax = float4(1.0, -1.0, -1.0, 1.0);
	float4 Bx = float4(0.5,  2.0, -0.5,-2.0);
	float4 Cx = float4(1.0,  1.0, -0.5, 0.0);
	float4 Ay = float4(1.0, -1.0, -1.0, 1.0);
	float4 By = float4(2.0,  0.5, -2.0,-0.5);
	float4 Cy = float4(2.0,  0.0, -1.0, 0.5);

	// These inequations define the line below which interpolation occurs.
	fx = (Ao*fp.y + Bo*fp.x > Co);
	fx_left = (Ax*fp.y + Bx*fp.x > Cx);
	fx_up = (Ay*fp.y + By*fp.x > Cy);

#ifdef CORNER_A
	interp_restriction_lv1 = ((e != f) && (e != h));
#endif
#ifdef CORNER_B
	interp_restriction_lv1 = ((e != f) && (e != h) && (!eq(f,b) && !eq(h,d) || eq(e,i) && !eq(f,i4) && !eq(h,i5) || eq(e,g) || eq(e,c)));
#endif
#ifdef CORNER_D
	float4 c1 = i4.yzwx;
	float4 g0 = i5.wxyz;
	interp_restriction_lv1 = ((e != f) && (e != h) && (!eq(f,b) && !eq(h,d) || eq(e,i) && !eq(f,i4) && !eq(h,i5) || eq(e,g) || eq(e,c)) && (f != f4 && f != i || h != h5 && h != i || h != g || f != c || eq(b,c1) && eq(d,g0)));
#endif
#ifdef CORNER_C
	interp_restriction_lv1 = ((e != f) && (e != h) && (!eq(f,b) && !eq(f,c) || !eq(h,d) && !eq(h,g) || eq(e,i) && (!eq(f,f4) && !eq(f,i4) || !eq(h,h5) && !eq(h,i5)) || eq(e,g) || eq(e,c)));
#endif

	interp_restriction_lv2_left = ((e != g) && (d != g));
	interp_restriction_lv2_up = ((e != c) && (b != c));

	float4 wd1 = weighted_distance(e, c, g, i, h5, f4, h, f);
	float4 wd2 = weighted_distance(h, d, i5, f, i4, b, e, i);

	edri = (wd1 <= wd2) && interp_restriction_lv1;
	edr = (wd1 <  wd2) && interp_restriction_lv1;

	edr = edr && (!edri.yzwx || !edri.wxyz);
	edr_left = ((XBR_LV2_COEFFICIENT*df(f,g)) <= df(h,c)) && interp_restriction_lv2_left && edr && (!edri.yzwx && eq(e,c));
	edr_up = (df(f,g) >= (XBR_LV2_COEFFICIENT*df(h,c))) && interp_restriction_lv2_up && edr && (!edri.wxyz && eq(e,g));


	nc = (edr && (fx || edr_left && fx_left || edr_up && fx_up));

	px = (df(e,f) <= df(e,h));

	float3 res1 = nc.x ? px.x ? F : H : nc.y ? px.y ? B : F : nc.z ? px.z ? D : B : E;
	float3 res2 = nc.w ? px.w ? H : D : nc.z ? px.z ? D : B : nc.y ? px.y ? B : F : E;

	float2 df12 = abs(mul(float2x3(res1, res2), Y) - e.xy);

	float3 res = lerp(res1, res2, step(df12.x, df12.y));

	return float4(res, 1.0);
	}

		ENDCG
	}
	}
		FallBack "Diffuse"
}