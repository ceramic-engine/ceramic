Shader "innerLight"
{
	Properties
	{
		[PerRendererData] _MainTex ("Main Texture", 2D) = "white" {}
		_SrcBlendRgb ("Src Rgb", Float) = 0
	 	_DstBlendRgb ("Dst Rgb", Float) = 0
		_SrcBlendAlpha ("Src Alpha", Float) = 0
	 	_DstBlendAlpha ("Dst Alpha", Float) = 0
		_StencilComp ("Stencil Comp", Float) = 8
		gap ("Gap", Vector) = (0,0,0,0)
		lightColor ("Light Color", Vector) = (0,0,0,0)
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
			float2 gap;
			fixed4 lightColor;

			fixed4 frag(v2f IN) : SV_Target
			{
				float2 uv = IN.texcoord;
				fixed4 pixel = tex2D(_MainTex, uv);
				fixed4 outsidePixel = tex2D(_MainTex, float2(uv.x + gap.x, uv.y - gap.y));

				pixel *= IN.color;

				float lightAlpha = (1.0 - outsidePixel.a) * lightColor.a * pixel.a;

				return fixed4(
					min(1.0, pixel.r + lightColor.r * lightAlpha),
					min(1.0, pixel.g + lightColor.g * lightAlpha),
					min(1.0, pixel.b + lightColor.b * lightAlpha),
					pixel.a
				);
			}
		ENDCG
		}
	}
}