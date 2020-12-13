Shader "bloom"
{
	Properties
	{
		[PerRendererData] _MainTex ("Main Texture", 2D) = "white" {}
		_SrcBlendRgb ("Src Rgb", Float) = 0
	 	_DstBlendRgb ("Dst Rgb", Float) = 0
		_SrcBlendAlpha ("Src Alpha", Float) = 0
	 	_DstBlendAlpha ("Dst Alpha", Float) = 0
		resolution ("resolution", Vector) = (0,0,0,0)
		bloomSpread ("bloomSpread", Float) = 1.0
		bloomIntensity ("bloomIntensity", Float) = 2.0
		bloomThreshold ("bloomThreshold", Float) = 0.5
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
			float bloomSpread;
			float bloomIntensity;
			float bloomThreshold;

			fixed4 frag(v2f IN) : SV_Target
			{
				fixed4 pixel;
				pixel = tex2D(_MainTex, IN.texcoord);

				if (pixel.a <= bloomThreshold) {
					float uvX = IN.texcoord.x;
					float uvY = IN.texcoord.y;

					fixed4 sum = fixed4(0.0, 0.0, 0.0, 0.0);
					for (int n = 0; n < 9; ++n) {
						uvY = IN.texcoord.y + (bloomSpread * (float(n) - 4.0)) / resolution.y;
						fixed4 hSum = fixed4(0.0, 0.0, 0.0, 0.0);
						hSum += tex2D(_MainTex, float2(uvX - (4.0 * bloomSpread) / resolution.x, uvY));
						hSum += tex2D(_MainTex, float2(uvX - (3.0 * bloomSpread) / resolution.x, uvY));
						hSum += tex2D(_MainTex, float2(uvX - (2.0 * bloomSpread) / resolution.x, uvY));
						hSum += tex2D(_MainTex, float2(uvX - bloomSpread / resolution.x, uvY));
						hSum += tex2D(_MainTex, float2(uvX, uvY));
						hSum += tex2D(_MainTex, float2(uvX + bloomSpread / resolution.x, uvY));
						hSum += tex2D(_MainTex, float2(uvX + (2.0 * bloomSpread) / resolution.x, uvY));
						hSum += tex2D(_MainTex, float2(uvX + (3.0 * bloomSpread) / resolution.x, uvY));
						hSum += tex2D(_MainTex, float2(uvX + (4.0 * bloomSpread) / resolution.x, uvY));
						sum += hSum / 9.0;
					}

					pixel = ((sum / 9.0) * bloomIntensity);
				}
				return pixel * IN.color;
			}
		ENDCG
		}
	}
}