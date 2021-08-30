Shader "stencil"
{
	Properties
	{
		_StencilRef ("Stencil Reference", Float) = 1
		_SrcBlendRgb ("Src Rgb", Float) = 0
	 	_DstBlendRgb ("Dst Rgb", Float) = 0
		_SrcBlendAlpha ("Src Alpha", Float) = 0
	 	_DstBlendAlpha ("Dst Alpha", Float) = 0
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

		ColorMask 0
		Cull Off
		Lighting Off
		ZWrite Off
		Blend [_SrcBlendRgb] [_DstBlendRgb], [_SrcBlendAlpha] [_DstBlendAlpha]

		Stencil {
			Ref [_StencilRef]
			Comp Always
			Pass Replace
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
				OUT.vertex = UnityObjectToClipPos(IN.vertex);
				OUT.texcoord = IN.texcoord;
				OUT.color = IN.color;

				return OUT;
			}

			sampler2D _MainTex;

			fixed4 frag(v2f IN) : SV_Target
			{
				return fixed4(1, 1, 1, 1) * IN.color;
			}
		ENDCG
		}
	}
}