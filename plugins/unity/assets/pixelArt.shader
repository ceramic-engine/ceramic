Shader "pixelArt"
{
	Properties
	{
		[PerRendererData] _MainTex ("Main Texture", 2D) = "white" {}
		_SrcBlendRgb ("Src Rgb", Float) = 0
     	_DstBlendRgb ("Dst Rgb", Float) = 0
		_SrcBlendAlpha ("Src Alpha", Float) = 0
     	_DstBlendAlpha ("Dst Alpha", Float) = 0
		resolution ("resolution", Vector) = (0,0,0,0)
		sharpness ("sharpness", Float) = 0.0
		gridThickness ("gridThickness", Float) = 0.0
		gridAlpha ("gridAlpha", Float) = 0.0
		gridColor ("gridColor", Vector) = (0,0,0,0)
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
			float sharpness;
			float gridThickness;
			float gridAlpha;
			float3 gridColor;

			// Ported from: https://gist.github.com/Beefster09/7264303ee4b4b2086f372f1e70e8eddd
			float sharpen(float px) {
				float norm = (frac(px) - 0.5) * 2.0;
				float norm2 = norm * norm;
				return floor(px) + norm * pow(norm2, sharpness) / 2.0 + 0.5;
			}

			float grid(float lineWidth, float gap, float2 uv) {

				// compute distance to closest horizontal and vertical line
				float2 dist = fmod(float2(uv.x + 0.5, uv.y + 0.5), gap) - 0.5 * gap;

				// return min distance to horizontal or vertical line
				return min(abs(dist.x), abs(dist.y));
			}

			fixed4 frag(v2f IN) : SV_Target
			{
				fixed4 texColor = tex2D(_MainTex, float2(
					sharpen(IN.texcoord.x * resolution.x) / resolution.x,
					sharpen(IN.texcoord.y * resolution.y) / resolution.y
				));

				if (gridThickness != 0.0) {
					float2 uv = float2(
						IN.texcoord.x * resolution.x,
						IN.texcoord.y * resolution.y
					);

					float gap = 1.0;

					// compute antialiased grid pattern
					float aLine = grid(gridThickness, gap, uv);
					float aa = smoothstep(0.0, 0.5, gridThickness - aLine); // adjust the "1.5" for different antialiasing sharpness

					aa *= gridAlpha;

					// mix grid and background color
					texColor.rgb = lerp(texColor.rgb, gridColor, aa);
				}

				return texColor * IN.color;
			}
		ENDCG
		}
	}
}