// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/XBR-LV2-Small-Details"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1) //You should set this field in Unity scripting, material.SetColor
		_MainTex("_MainTex (RGB)", 2D) = "white" {} //you should also set this in scripting with material.SetTexture ("_MainTex", your_MainTexTexture)
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
		Hyllian's xBR-lv2-small-details Shader

		Copyright (C) 2011-2017 Hyllian - sergiogdb@gmail.com

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
		Leonardo da Luz Pinto's xBR-lv2-small-details Adaptation to Unity ShaderLab

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
#define XBR_Y_WEIGHT 48.0
#define XBR_EQ_THRESHOLD 10.0
#define XBR_LV2_COEFFICIENT 2.0
#define XBR_STRENGTH 0.1


		uniform COMPAT_Texture2D(_MainTex) : TEXUNIT0;

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

	float c_df(float3 c1, float3 c2)
	{
		float3 df = abs(c1 - c2);
		return df.r + df.g + df.b;
	}

	bool4 eq(float4 A, float4 B)
	{
		return (df(A, B) < float4(XBR_EQ_THRESHOLD, XBR_EQ_THRESHOLD, XBR_EQ_THRESHOLD, XBR_EQ_THRESHOLD));
	}

	float4 weighted_distance(float4 a, float4 b, float4 c, float4 d, float4 e, float4 f, float4 g, float4 h, float4 i, float4 j, float4 k, float4 l)
	{
		return (df(a, b) + df(a, c) + df(d, e) + df(d, f) + df(i, j) + df(k, l) + 2.0*df(g, h));
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
		float scale : TEXCOORD8;

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

		OUT.texCoord = v.texcoord +float2(0.0000001, 0.0000001);
		OUT.t1 = v.texcoord.xxxy + float4(-dx, 0, dx, -2.0*dy); // A1 B1 C1
		OUT.t2 = v.texcoord.xxxy + float4(-dx, 0, dx, -dy); // A B C
		OUT.t3 = v.texcoord.xxxy + float4(-dx, 0, dx, 0); // D E F
		OUT.t4 = v.texcoord.xxxy + float4(-dx, 0, dx, dy); // G H I
		OUT.t5 = v.texcoord.xxxy + float4(-dx, 0, dx, 2.0*dy); // G5 H5 I5
		OUT.t6 = v.texcoord.xyyy + float4(-2.0*dx, -dy, 0, dy); // A0 D0 G0
		OUT.t7 = v.texcoord.xyyy + float4(2.0*dx, -dy, 0, dy); // C4 F4 I4
		OUT.scale = 2 + 1.0;
		return OUT;
	}





	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{

		bool4 edri, edr, edr_left, edr_up, px; // px = pixel, edr = edge detection rule
	bool4 interp_restriction_lv0, interp_restriction_lv1, interp_restriction_lv2_left, interp_restriction_lv2_up;
	float4 fx, fx_left, fx_up; // inequations of straight lines.

	float4 delta = float4(1.0 / VAR.scale, 1.0 / VAR.scale, 1.0 / VAR.scale, 1.0 / VAR.scale);
	float4 deltaL = float4(0.5 / VAR.scale, 1.0 / VAR.scale, 0.5 / VAR.scale, 1.0 / VAR.scale);
	float4 deltaU = deltaL.yxwz;
	float4 Ci = 0.1 / delta;

	float2 fp = frac(VAR.texCoord*texture_size);

	float3 A1 = tex2D(_MainTex, VAR.t1.xw).rgb;
	float3 B1 = tex2D(_MainTex, VAR.t1.yw).rgb;
	float3 C1 = tex2D(_MainTex, VAR.t1.zw).rgb;

	float3 A = tex2D(_MainTex, VAR.t2.xw).rgb;
	float3 B = tex2D(_MainTex, VAR.t2.yw).rgb;
	float3 C = tex2D(_MainTex, VAR.t2.zw).rgb;

	float3 D = tex2D(_MainTex, VAR.t3.xw).rgb;
	float3 E = tex2D(_MainTex, VAR.t3.yw).rgb;
	float3 F = tex2D(_MainTex, VAR.t3.zw).rgb;

	float3 G = tex2D(_MainTex, VAR.t4.xw).rgb;
	float3 H = tex2D(_MainTex, VAR.t4.yw).rgb;
	float3 I = tex2D(_MainTex, VAR.t4.zw).rgb;

	float3 G5 = tex2D(_MainTex, VAR.t5.xw).rgb;
	float3 H5 = tex2D(_MainTex, VAR.t5.yw).rgb;
	float3 I5 = tex2D(_MainTex, VAR.t5.zw).rgb;

	float3 A0 = tex2D(_MainTex, VAR.t6.xy).rgb;
	float3 D0 = tex2D(_MainTex, VAR.t6.xz).rgb;
	float3 G0 = tex2D(_MainTex, VAR.t6.xw).rgb;

	float3 C4 = tex2D(_MainTex, VAR.t7.xy).rgb;
	float3 F4 = tex2D(_MainTex, VAR.t7.xz).rgb;
	float3 I4 = tex2D(_MainTex, VAR.t7.xw).rgb;

	float4 b = mul(float4x3(B, D, H, F), XBR_Y_WEIGHT*Y);
	float4 c = mul(float4x3(C, A, G, I), XBR_Y_WEIGHT*Y);
	float4 e = mul(float4x3(E, E, E, E), XBR_Y_WEIGHT*Y);
	float4 d = b.yzwx;
	float4 f = b.wxyz;
	float4 g = c.zwxy;
	float4 h = b.zwxy;
	float4 i = c.wxyz;

	float4 i4 = mul(float4x3(I4, C1, A0, G5), XBR_Y_WEIGHT*Y);
	float4 i5 = mul(float4x3(I5, C4, A1, G0), XBR_Y_WEIGHT*Y);
	float4 h5 = mul(float4x3(H5, F4, B1, D0), XBR_Y_WEIGHT*Y);
	float4 f4 = h5.yzwx;

	// These inequations define the line below which interpolation occurs.
	fx = (Ao*fp.y + Bo*fp.x);
	fx_left = (Ax*fp.y + Bx*fp.x);
	fx_up = (Ay*fp.y + By*fp.x);

	interp_restriction_lv1 = ((e != f) && (e != h) && (h != g && eq(e,g) || f != c && eq(e,c)));

	interp_restriction_lv2_left = ((e != g) && (d != g));
	interp_restriction_lv2_up = ((e != c) && (b != c));

	float4 fx45i = saturate((fx + delta - Co - Ci) / (2 * delta));
	float4 fx45 = saturate((fx + delta - Co) / (2 * delta));
	float4 fx30 = saturate((fx_left + deltaL - Cx) / (2 * deltaL));
	float4 fx60 = saturate((fx_up + deltaU - Cy) / (2 * deltaU));

	float4 wd1 = weighted_distance(e, c, g, i, f4, h5, h, f, b, d, i4, i5);
	float4 wd2 = weighted_distance(h, d, i5, f, b, i4, e, i, g, h5, c, f4);

	edr = interp_restriction_lv1 && (wd1 <  (wd2 - float4(XBR_STRENGTH*100.0, XBR_STRENGTH*100.0, XBR_STRENGTH*100.0, XBR_STRENGTH*100.0)));
	edri = !edr && (wd1 <= wd2);
	edr_left = ((XBR_LV2_COEFFICIENT*df(f,g)) <= df(h,c)) && interp_restriction_lv2_left && edr && (!edri.yzwx);
	edr_up = (df(f,g) >= (XBR_LV2_COEFFICIENT*df(h,c))) && interp_restriction_lv2_up && edr && (!edri.wxyz);

	fx45 = edr*fx45;
	fx30 = edr_left*fx30;
	fx60 = edr_up*fx60;
	fx45i = edri*fx45i;

	px = (df(e,f) <= df(e,h));

	float4 maximos = max(max(fx30, fx60), max(fx45, fx45i));

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