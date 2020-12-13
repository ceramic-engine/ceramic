Shader "outline"
{
	Properties
	{
		[PerRendererData] _MainTex ("Main Texture", 2D) = "white" {}
		_SrcBlendRgb ("Src Rgb", Float) = 0
	 	_DstBlendRgb ("Dst Rgb", Float) = 0
		_SrcBlendAlpha ("Src Alpha", Float) = 0
	 	_DstBlendAlpha ("Dst Alpha", Float) = 0
		resolution ("resolution", Vector) = (0,0,0,0)
		outlineThickness ("outlineThickness", Float) = 1.0
		outlineColor ("outlineColor", Vector) = (0,0,1,0)
		outlineThreshold ("outlineThreshold", Float) = 0.5
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
			float outlineThickness;
			fixed3 outlineColor;
			float outlineThreshold;

			fixed4 frag(v2f IN) : SV_Target
			{
				fixed4 pixel;
				pixel = tex2D(_MainTex, IN.texcoord);
				float thickness = outlineThickness * 0.25;
				if (pixel.a <= outlineThreshold) {
				
					float uvX = IN.texcoord.x;
					float uvY = IN.texcoord.y;

					float sum = 0.0;
					for (int n = 0; n < 9; ++n) {
						uvY = IN.texcoord.y + (thickness * (float(n) - 4.5)) / resolution.y;
						float hSum = 0.0;
						hSum += tex2D(_MainTex, float2(uvX - (4.0 * thickness) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX - (3.0 * thickness) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX - (2.0 * thickness) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX - thickness / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX + thickness / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX + (2.0 * thickness) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX + (3.0 * thickness) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX + (4.0 * thickness) / resolution.x, uvY)).a;
						sum += hSum / 9.0;
					}

					if (sum / 9.0 >= 0.0001) {
						pixel = fixed4(outlineColor, 1);
					}
				}
				return pixel * IN.color;
			}
		ENDCG
		}
	}
}