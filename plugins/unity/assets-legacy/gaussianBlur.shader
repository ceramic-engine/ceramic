Shader "gaussianBlur"
{
	Properties
	{
		[PerRendererData] _MainTex ("Main Texture", 2D) = "white" {}
		_SrcBlendRgb ("Src Rgb", Float) = 0
	 	_DstBlendRgb ("Dst Rgb", Float) = 0
		_SrcBlendAlpha ("Src Alpha", Float) = 0
	 	_DstBlendAlpha ("Dst Alpha", Float) = 0
		_StencilComp ("Stencil Comp", Float) = 8
		resolution ("Resolution", Vector) = (0,0,0,0)
		blurSize ("Blur Size", Vector) = (0,0,0,0)
	}

	SubShader
	{
		Tags
		{
			"Queue"="Transparent"
			"IgnoreProjector"="True"
			"RenderType"="Transparent"
			"PreviewType"="Plane"
			"CanUseSpriteAtlas"="True"
		}

		Cull Off
		Lighting Off
		ZWrite Off
		Blend [_SrcBlendRgb] [_DstBlendRgb], [_SrcBlendAlpha] [_DstBlendAlpha]

		Stencil {
			Ref 1
			Comp [_StencilComp]
		}

		Pass
		{
		CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata_t
			{
				float4 vertex   : POSITION;
				float4 color    : COLOR;
				float2 texcoord : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex   : SV_POSITION;
				fixed4 color    : COLOR;
				float2 texcoord  : TEXCOORD0;
			};

			v2f vert(appdata_t IN)
			{
				v2f OUT;
				OUT.vertex = UnityObjectToClipPos(IN.vertex.xyz);
				OUT.texcoord = IN.texcoord;
				OUT.color = IN.color;

				return OUT;
			}

			sampler2D _MainTex;
			float2 resolution;
			float2 blurSize;

			// Shader ported from: https://github.com/Jam3/glsl-fast-gaussian-blur

			fixed4 frag(v2f IN) : SV_Target
			{
				float pi2 = 6.28318530718; // Pi*2

				//float directions = 16.0; // BLUR DIRECTIONS (Default 16.0 - More is better but slower)
				//float quality = 3.0; // BLUR QUALITY (Default 4.0 - More is better but slower)
				//float size = 8.0; // BLUR SIZE (Radius)

				float2 radius = blurSize / resolution.xy;

				// Normalized pixel coordinates (from 0 to 1)
				float2 uv = IN.texcoord;

				fixed4 pixel = tex2D(_MainTex, uv);

				// Blur calculations
				for (float d = 0.0; d < /*pi2*/6.28318530718; d += /*pi2*/6.28318530718 / /*directions*/16.0)
				{
					float2 dir = float2(cos(d), sin(d)) * radius;
					for (float i = 1.0 / /*quality*/4.0; i <= 1.0; i += 1.0 / /*quality*/4.0)
					{
						pixel += tex2D(_MainTex, uv + dir * i);
					}
				}

				// Output to screen
				pixel /= /*quality*/4.0 * /*directions*/16.0;
				return IN.color * pixel;
			}
		ENDCG
		}
	}
}