// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Pixel Art Filters/DDT"
{
	Properties
	{
		_BackgroundTexture("decal (RGB)", 2D) = "white" {} //you should also set this in scripting with material.SetTexture ("decal", yourDecalTexture)
	texture_size("texture_size", Vector) = (256,224,0,0)
		//blur_Texture_Size("texture_size", Vector) = (512,448,0,0)
	}
		SubShader
	{
		Tags{ "RenderType" = "Opaque" }
		///////////////////////////////////
		Pass   
	{
		CGPROGRAM
#include "UnityCG.cginc"
#pragma vertex main_vertex
#pragma fragment main_fragment
#pragma target 3.0

		sampler2D _BackgroundTexture : TEXUNIT0;

	uniform float2 texture_size; // set from outside the shader ( THIS NOTE WAS MADE BY SONOSHEE)	
	  

#include "ddt-1st-Pass.txt"

	ENDCG
	}
	}
		FallBack "Diffuse"
}