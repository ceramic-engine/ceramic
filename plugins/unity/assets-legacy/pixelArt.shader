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
		sharpness ("sharpness", Float) = 0

		gridThickness ("gridThickness", Float) = 0
		gridAlpha ("gridAlpha", Float) = 0
		gridColor ("gridColor", Vector) = (0,0,0,0)

		scanlineIntensity ("scanlineIntensity", Float) = 0
		scanlineOffset ("scanlineOffset", Float) = 0
		scanlineCount ("scanlineCount", Float) = 0
		scanlineShape ("scanlineShape", Float) = 0

		verticalMaskIntensity ("verticalMaskIntensity", Float) = 0
		verticalMaskOffset ("verticalMaskOffset", Float) = 0
		verticalMaskCount ("verticalMaskCount", Float) = 0

		glowThresholdMin ("glowThresholdMin", Float) = 0
		glowThresholdMax ("glowThresholdMax", Float) = 0
		glowStrength ("glowStrength", Float) = 0

		chromaticAberration ("chromaticAberration", Float) = 0
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

			float scanlineIntensity;
			float scanlineOffset;
			float scanlineCount;
			float scanlineShape;

			float verticalMaskIntensity;
			float verticalMaskOffset;
			float verticalMaskCount;

			float glowThresholdMin;
			float glowThresholdMax;
			float glowStrength;

			float chromaticAberration;

			// Ported from: https://gist.github.com/Beefster09/7264303ee4b4b2086f372f1e70e8eddd
			float sharpen(float px) {
				float norm = (frac(px) - 0.5) * 2.0;
				float norm2 = norm * norm;
				return floor(px) + norm * pow(norm2, sharpness) / 2.0 + 0.5;
			}

			// Helper function to sample texture with sharpness applied
			fixed4 sampleSharpened(sampler2D tex, float2 coord) {
				return tex2D(tex, float2(
					sharpen(coord.x * resolution.x) / resolution.x,
					sharpen(coord.y * resolution.y) / resolution.y
				));
			}

			float grid(float lineWidth, float gap, float2 uv) {
				// compute distance to closest horizontal and vertical line
				float2 dist = fmod(float2(uv.x + 0.5, uv.y + 0.5), gap) - 0.5 * gap;

				// return min distance to horizontal or vertical line
				return min(abs(dist.x), abs(dist.y));
			}

			fixed4 frag(v2f IN) : SV_Target
			{
				fixed4 texColor;

				// Chromatic Aberration
				if (chromaticAberration > 0.0) {
					float2 aberr = float2(chromaticAberration, 0.0); // horizontal offset

					// Apply sharpness to each color channel separately
					float r = sampleSharpened(_MainTex, IN.texcoord + aberr).r;
					float g = sampleSharpened(_MainTex, IN.texcoord).g;
					float b = sampleSharpened(_MainTex, IN.texcoord - aberr).b;

					texColor = fixed4(r, g, b, 1.0);
				}
				else {
					texColor = sampleSharpened(_MainTex, IN.texcoord);
				}

				// Grid
				if (gridThickness > 0.0) {
					float2 uv = float2(
						IN.texcoord.x * resolution.x,
						IN.texcoord.y * resolution.y
					);

					float gap = 1.0;

					// compute antialiased grid pattern
					float aLine = grid(gridThickness, gap, uv);
					float aa = smoothstep(0.0, 0.5, gridThickness - aLine);

					aa *= gridAlpha;

					// mix grid and background color
					texColor.rgb = lerp(texColor.rgb, gridColor, aa);
				}

				// Scanlines
				float lum = dot(texColor.rgb, float3(0.2126, 0.7152, 0.0722));
				if (scanlineCount > 0.0) {
					float scanY = sin(((scanlineOffset / scanlineCount) + IN.texcoord.y) * scanlineCount * 3.14159);
					scanY = (scanY * 0.5 + 0.5);           // now in [0, 1]
					scanY = pow(scanY, lerp(scanlineShape, min(scanlineShape, 1.0), lum));     // shape the curve
					float scanFactor = lerp(scanlineIntensity, 1.0, scanY);
					texColor.rgb *= scanFactor;
				}

				// Vertical Shadow Mask
				if (verticalMaskCount > 0.0) {
					float scanX = sin(((verticalMaskOffset / verticalMaskCount) + IN.texcoord.x) * verticalMaskCount * 3.14159);
					float maskFactor = lerp(verticalMaskIntensity, 1.0, scanX * 0.5 + 0.5);
					texColor.rgb *= maskFactor;
				}

				// Bloom / Glow
				if (glowStrength > 0.0) {
					float glowFactor = smoothstep(glowThresholdMin, glowThresholdMax, lum);
					if (glowFactor > 0.0) {
						float2 texel = 1.0 / resolution;
						float3 blur = tex2D(_MainTex, IN.texcoord + float2(texel.x, 0.0)).rgb;
						blur += tex2D(_MainTex, IN.texcoord - float2(texel.x, 0.0)).rgb;
						blur += tex2D(_MainTex, IN.texcoord + float2(0.0, texel.y)).rgb;
						blur += tex2D(_MainTex, IN.texcoord - float2(0.0, texel.y)).rgb;
						blur += texColor.rgb;
						blur /= 5.0;
						texColor.rgb = lerp(texColor.rgb, blur, glowFactor * glowStrength);
					}
				}

				texColor.a = 1.0;

				return texColor * IN.color;
			}
		ENDCG
		}
	}
}