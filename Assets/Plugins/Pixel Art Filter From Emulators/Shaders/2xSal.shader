// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/2xSal"
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
#pragma target 2.0

		/* COMPATIBILITY
		- HLSL compilers
		- Cg   compilers
		- FX11 compilers
		*/

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
		/*
		Leonardo da Luz Pinto's 2xSal Adaptation to Unity ShaderLab

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
#include "compat_includes.inc"


		uniform half4 _Color;
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
		float4 color : COLOR;
		float2 texCoord : TEXCOORD0;

	};
	float4 two_xsal(float2 texture_size, float2 texCoord, COMPAT_Texture2D(decal))
	{
		float2 texsize = texture_size;
		float dx = pow(texsize.x, -1.0) * 0.25;
		float dy = pow(texsize.y, -1.0) * 0.25;
		float3 dt = float3(1.0, 1.0, 1.0);

		float2 UL = texCoord + float2(-dx, -dy);
		float2 UR = texCoord + float2(dx, -dy);
		float2 DL = texCoord + float2(-dx, dy);
		float2 DR = texCoord + float2(dx, dy);

		float3 c00 = COMPAT_SamplePoint(decal, UL).xyz;
		float3 c20 = COMPAT_SamplePoint(decal, UR).xyz;
		float3 c02 = COMPAT_SamplePoint(decal, DL).xyz;
		float3 c22 = COMPAT_SamplePoint(decal, DR).xyz;

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

		OUT.texCoord = v.texcoord + float2(-0.001, 0.001);


		return OUT;
	}

	//FRAGMENT SHADER
	half4 main_fragment(out_vertex VAR) : COLOR
	{ 
		return two_xsal(texture_size, VAR.texCoord, decal);
	}


		ENDCG
	}
	}
		FallBack "Diffuse"
}