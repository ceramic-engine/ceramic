Shader "msdf"
{
	Properties
	{
		[PerRendererData] _MainTex ("Main Texture", 2D) = "white" {}
		_SrcBlendRgb ("Src Rgb", Float) = 0
     	_DstBlendRgb ("Dst Rgb", Float) = 0
		_SrcBlendAlpha ("Src Alpha", Float) = 0
     	_DstBlendAlpha ("Dst Alpha", Float) = 0
		texSize ("texSize", Vector) = (0,0,0,0)
		pxRange ("pxRange", Float) = 0.0
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
				OUT.vertex = UnityObjectToClipPos(IN.vertex);
				OUT.texcoord = IN.texcoord;
				OUT.color = IN.color;

				return OUT;
			}

			sampler2D _MainTex;
			float2 texSize;
			float pxRange;

			float median(float r, float g, float b) {
				return max(min(r, g), min(max(r, g), b));
			}

			fixed4 frag(v2f IN) : SV_Target
			{
				float2 msdfUnit;
				float3 sample;
				msdfUnit = pxRange/texSize;
				sample = tex2D(_MainTex, IN.texcoord).rgb;
				float sigDist = median(sample.r, sample.g, sample.b) - 0.5;
				sigDist = mul(sigDist, dot(msdfUnit, 0.5/fwidth(IN.texcoord)));
				float opacity = clamp(sigDist + 0.5, 0.0, 1.0);
				fixed4 bgColor = fixed4(0.0, 0.0, 0.0, 0.0);
				fixed4 c = lerp(bgColor, IN.color, opacity);
				return c;
			}
		ENDCG
		}
	}
}