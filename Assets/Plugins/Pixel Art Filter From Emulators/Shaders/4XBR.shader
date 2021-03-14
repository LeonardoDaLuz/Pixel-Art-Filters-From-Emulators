// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/4xBR"
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
#pragma vertex main_vertex
#pragma fragment main_fragment
#pragma target 3.0


	uniform sampler2D decal : TEXUNIT0;

	float2 texture_size; // set from outside the shader ( THIS NOTE WAS MADE BY SONOSHEE)

	const static float coef = 2.0;
	const static float4 XBR_EQ_THRESHOLD = float4(15.0, 15.0, 15.0, 15.0);
	const static float y_weight = 48.0;
	const static float u_weight = 7.0;
	const static float v_weight = 6.0;
	const static float3x3 yuv = float3x3(0.299, 0.587, 0.114, -0.169, -0.331, 0.499, 0.499, -0.418, -0.0813);
	const static float3x3 yuv_weighted = float3x3(y_weight*yuv[0], u_weight*yuv[1], v_weight*yuv[2]);
	const static float4 delta = float4(0.5, 0.5, 0.5, 0.5);
	const static float sharpness = 0.65;
	const static float3 dtt = float3(65536, 255, 1);

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


	float4 weighted_distance(float4 a, float4 b, float4 c, float4 d, float4 e, float4 f, float4 g, float4 h)
	{
		return (df(a, b) + df(a, c) + df(d, e) + df(d, f) + 4.0*df(g, h));
	}

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
#define FILTRO(PE, PI, PH, PF, PG, PC, PD, PB, PA, G5, C4, G0, C1, I4, I5, N15, N14, N11, F, H) \
	if ( PE!=PH && ((PH==PF && ( (PE!=PI && (PE!=PB || PE!=PD || PB==C1 && PD==G0 || PF!=PB && PF!=PC || PH!=PD && PH!=PG)) \
	   || (PE==PG && (PI==PH || PE==PD || PH!=PD)) \
	   || (PE==PC && (PI==PH || PE==PB || PF!=PB)) ))\
	   || (PE!=PF && (PE==PC && (PF!=PI && (PH==PI && PF!=PB || PE!=PI && PF==C4) || PE!=PI && PE==PG)))) ) \
                 {\
	                N11 = (N11+F)*0.5;\
        	        N14 = (N14+H)*0.5;\
                	N15 = F;\
                 }\
	else if (PE!=PH && PE!=PF && (PH!=PI && PE==PG && (PF==PI && PH!=PD || PE!=PI && PH==G5)))\
	{\
                N11 = (N11+H)*0.5;\
                N14 = N11;\
                N15 = H;\
	}\


	float reduce(half3 color)
	{
		return dot(color, dtt);
	}
	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{
		 
		bool4 edr, edr_left, edr_up, px; // px = pixel, edr = edge detection rule
	bool4 interp_restriction_lv1, interp_restriction_lv2_left, interp_restriction_lv2_up;
	bool4 nc; // new_color
	bool4 fx, fx_left, fx_up; // inequations of straight lines.

	float2 fp = frac(VAR.texCoord*texture_size);

	half3 A1 = tex2D(decal, VAR.t1.xw).rgb;
	half3 B1 = tex2D(decal, VAR.t1.yw).rgb;
	half3 C1 = tex2D(decal, VAR.t1.zw).rgb;

	half3 A = tex2D(decal, VAR.t2.xw).rgb;
	half3 B = tex2D(decal, VAR.t2.yw).rgb;
	half3 C = tex2D(decal, VAR.t2.zw).rgb;

	half3 D = tex2D(decal, VAR.t3.xw).rgb;
	half3 E = tex2D(decal, VAR.t3.yw).rgb;
	half3 F = tex2D(decal, VAR.t3.zw).rgb;

	half3 G = tex2D(decal, VAR.t4.xw).rgb;
	half3 H = tex2D(decal, VAR.t4.yw).rgb;
	half3 I = tex2D(decal, VAR.t4.zw).rgb;

	half3 G5 = tex2D(decal, VAR.t5.xw).rgb;
	half3 H5 = tex2D(decal, VAR.t5.yw).rgb;
	half3 I5 = tex2D(decal, VAR.t5.zw).rgb;

	half3 A0 = tex2D(decal, VAR.t6.xy).rgb;
	half3 D0 = tex2D(decal, VAR.t6.xz).rgb;
	half3 G0 = tex2D(decal, VAR.t6.xw).rgb;

	half3 C4 = tex2D(decal, VAR.t7.xy).rgb;
	half3 F4 = tex2D(decal, VAR.t7.xz).rgb;
	half3 I4 = tex2D(decal, VAR.t7.xw).rgb;

	float4 b = mul(half4x3(B, D, H, F), yuv_weighted[0]);
	float4 c = mul(half4x3(C, A, G, I), yuv_weighted[0]);
	float4 e = mul(half4x3(E, E, E, E), yuv_weighted[0]);
	float4 d = b.yzwx;
	float4 f = b.wxyz;
	float4 g = c.zwxy;
	float4 h = b.zwxy;
	float4 i = c.wxyz;

	float4 i4 = mul(half4x3(I4, C1, A0, G5), yuv_weighted[0]);
	float4 i5 = mul(half4x3(I5, C4, A1, G0), yuv_weighted[0]);
	float4 h5 = mul(half4x3(H5, F4, B1, D0), yuv_weighted[0]);
	float4 f4 = h5.yzwx;

	interp_restriction_lv1 = ((e != f) && (e != h) && (!eq(f,b) && !eq(f,c) || !eq(h,d) && !eq(h,g) || eq(e,i) && (!eq(f,f4) && !eq(f,i4) || !eq(h,h5) && !eq(h,i5)) || eq(e,g) || eq(e,c)));
	interp_restriction_lv2_left = ((e != g) && (d != g));
	interp_restriction_lv2_up = ((e != c) && (b != c));



	edr = (weighted_distance(e, c, g, i, h5, f4, h, f) < weighted_distance(h, d, i5, f, i4, b, e, i)) && interp_restriction_lv1;
	edr_left = ((coef*df(f,g)) <= df(h,c)) && interp_restriction_lv2_left;
	edr_up = (df(f,g) >= (coef*df(h,c))) && interp_restriction_lv2_up;

	px = (df(e,f) <= df(e,h));

	half3 P[4];
	P[0] = px.x ? F : H;
	P[1] = px.y ? B : F;
	P[2] = px.z ? D : B;
	P[3] = px.w ? H : D;

	half3 res = E;


	float3 n1, n2, n3, n4, s, aa, bb, cc, dd, threshold, xx;
	bool3 sim1, sim2;

	threshold = float3(0.4,0,0);
	xx = float3(0.0,0,0);

	n1 = B1; n2 = B; s = E; n3 = H; n4 = H5;
	aa = n2 - n1; bb = s - n2; cc = n3 - s; dd = n4 - n3;

	float3 t = (7 * (bb + cc) - 3 * (aa + dd)) / 16;

	float3 m = (s < 0.5) ? 2 * s : 2 * (1.0 - s);

	m = min(m, 2 * abs(bb));
	m = min(m, 2 * abs(cc));
	sim1 = (((abs(bb) * 2)> threshold) || ((abs(cc) * 2) > threshold) || ((abs(bb) * 2) <= xx) || ((abs(cc) * 2) <= xx));
	t = clamp(t, -m, m);


	float3 s1 = (2 * fp.y - 1)*t + s;

	n1 = D0; n2 = D; s = s1; n3 = F; n4 = F4;
	aa = n2 - n1; bb = s - n2; cc = n3 - s; dd = n4 - n3;

	t = (7 * (bb + cc) - 3 * (aa + dd)) / 16;

	m = (s < 0.5) ? 2 * s : 2 * (1.0 - s);

	m = min(m, 2 * abs(bb));
	m = min(m, 2 * abs(cc));
	sim2 = (((abs(bb) * 2)> threshold) || ((abs(cc) * 2) > threshold) || ((abs(bb) * 2) <= xx) || ((abs(cc) * 2) <= xx));
	t = clamp(t, -m, m);

	float3 s0 = (2 * fp.x - 1)*t + s;

	res = s0;

	if (any(sim1) && any(sim2))
	{
		if (fp.x >= 0.5)
		{
			if (fp.y >= 0.5)
			{
				if (edr.x && edr_left.x && edr_up.x)
				{
					res = lerp(E , P[0],  0.833333);
				}
				else if (edr.x && (edr_left.x || edr_up.x))
				{
					res = lerp(E , P[0],  0.75);
				}
				else if (edr.y && edr_left.y && edr.w && edr_up.w)
				{
					res = lerp(E , P[1],  0.25);
					res = lerp(E , P[3],  0.25);
				}
				else if (edr.y && edr_left.y)
				{
					res = lerp(E , P[1],  0.25);
				}
				else if (edr.w && edr_up.w)
				{
					res = lerp(E , P[3],  0.25);
				}
				else if (edr.x)
				{
					res = lerp(E , P[0],  0.5);
				}
			}
			else
			{
				if (edr.y && edr_left.y && edr_up.y)
				{
					res = lerp(E , P[1],  0.833333);
				}
				else if (edr.y && (edr_left.y || edr_up.y))
				{
					res = lerp(E , P[1],  0.75);
				}
				else if (edr.z && edr_left.z && edr.x && edr_up.x)
				{
					res = lerp(E , P[2],  0.25);
					res = lerp(E , P[0],  0.25);
				}
				else if (edr.z && edr_left.z)
				{
					res = lerp(E , P[2],  0.25);
				}
				else if (edr.x && edr_up.x)
				{
					res = lerp(E , P[0],  0.25);
				}
				else if (edr.y)
				{
					res = lerp(E , P[1],  0.5);
				}
			}
		}
		else
		{
			if (fp.y >= 0.5)
			{
				if (edr.w && edr_left.w && edr_up.w)
				{
					res = lerp(E , P[3],  0.833333);
				}
				else if (edr.w && (edr_left.w || edr_up.w))
				{
					res = lerp(E , P[3],  0.75);
				}
				else if (edr.x && edr_left.x && edr.z && edr_up.z)
				{
					res = lerp(E , P[0],  0.25);
					res = lerp(E , P[2],  0.25);
				}
				else if (edr.x && edr_left.x)
				{
					res = lerp(E , P[0],  0.25);
				}
				else if (edr.z && edr_up.z)
				{
					res = lerp(E , P[2],  0.25);
				}
				else if (edr.w)
				{
					res = lerp(E , P[3],  0.5);
				}
			}
			else
			{
				if (edr.z && edr_left.z && edr_up.z)
				{
					res = lerp(E , P[2],  0.833333);
				}
				else if (edr.z && (edr_left.z || edr_up.z))
				{
					res = lerp(E , P[2],  0.75);
				}
				else if (edr.w && edr_left.w && edr.y && edr_up.y)
				{
					res = lerp(E , P[3],  0.25);
					res = lerp(E , P[1],  0.25);
				}
				else if (edr.w && edr_left.w)
				{
					res = lerp(E , P[3],  0.25);
				}
				else if (edr.y && edr_up.y)
				{
					res = lerp(E , P[1],  0.25);
				}
				else if (edr.z)
				{
					res = lerp(E , P[2],  0.5);
				}
			}
		}
	}





	return half4(res, 1.0);
	}

		ENDCG
	}
	}
		FallBack "Diffuse"
}