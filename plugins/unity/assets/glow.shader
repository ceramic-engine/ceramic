Shader "glow"
{
	Properties
	{
		[PerRendererData] _MainTex ("Main Texture", 2D) = "white" {}
		_SrcBlendRgb ("Src Rgb", Float) = 0
	 	_DstBlendRgb ("Dst Rgb", Float) = 0
		_SrcBlendAlpha ("Src Alpha", Float) = 0
	 	_DstBlendAlpha ("Dst Alpha", Float) = 0
		resolution ("resolution", Vector) = (0,0,0,0)
		glowSize ("glowSize", Float) = 0.5
		glowColor ("glowColor", Vector) = (0,0,0,0)
		glowIntensity ("glowIntensity", Float) = 1.0
		glowThreshold ("glowThreshold", Float) = 0.5
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
			float glowSize;
			fixed3 glowColor;
			float glowThreshold;
			float glowIntensity;

			fixed4 frag(v2f IN) : SV_Target
			{
				fixed4 pixel;
				pixel = tex2D(_MainTex, IN.texcoord);
				if (pixel.a <= glowThreshold) {
				
					float uvX = IN.texcoord.x;
					float uvY = IN.texcoord.y;

					float sum = 0.0;
					for (int n = 0; n < 9; ++n) {
						uvY = IN.texcoord.y + (glowSize * (float(n) - 4.0)) / resolution.y;
						float hSum = 0.0;
						hSum += tex2D(_MainTex, float2(uvX - (4.0 * glowSize) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX - (3.0 * glowSize) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX - (2.0 * glowSize) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX - glowSize / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX + glowSize / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX + (2.0 * glowSize) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX + (3.0 * glowSize) / resolution.x, uvY)).a;
						hSum += tex2D(_MainTex, float2(uvX + (4.0 * glowSize) / resolution.x, uvY)).a;
						sum += hSum / 9.0;
					}

					float a = (sum / 9.0) * glowIntensity;
					pixel = fixed4(a * glowColor, a);
				}
				return pixel * IN.color;
			}
		ENDCG
		}
	}
}