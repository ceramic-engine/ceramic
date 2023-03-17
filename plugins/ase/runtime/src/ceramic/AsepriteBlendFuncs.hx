package ceramic;

//
// This Haxe code is mostly ported from aseprite source code: https://github.com/aseprite/aseprite/blob/23557a190b4f5ab46c9b3ddb19146a7dcfb9dd82/src/doc/blend_funcs.cpp
//
// -- Original header --
// Aseprite Document Library
// Copyright (c) 2019-2022 Igara Studio S.A.
// Copyright (c) 2001-2017 David Capello
//
// This file is released under the terms of the MIT license.
// Read LICENSE.txt for more information.
//
// --
//
// Some references about alpha compositing and blend modes:
//
//   http://dev.w3.org/fxtf/compositing-1/
//   http://www.adobe.com/devnet/pdf/pdf_reference.html
//

/**
 * Blending function that operate at pixel/color level, ported from Aseprite source code.
 */
class AsepriteBlendFuncs {

    static var _float_r:Float = 0;

    static var _float_g:Float = 0;

    static var _float_b:Float = 0;

    inline static final A_MASK:Int = 0xFF000000;

    inline static final RGB_MASK:Int = 0x00FFFFFF;

    inline static final A_SHIFT:Int = 24;

    public inline static function min(a:Int, b:Int):Int {
        return a < b ? a : b;
    }

    public inline static function max(a:Int, b:Int):Int {
        return a > b ? a : b;
    }

    public inline static function abs(v:Int):Int {
        return v < 0 ? -v : v;
    }

    public inline static function half(v:Int):Int {
        #if cpp
        return untyped __cpp__('({0}/2)', v);
        #elseif cs
        return untyped __cs__('({0}/2)', v);
        #elseif js
        return js.Syntax.code('({0}/2)>>0', v);
        #else
        return Std.int(v/2);
        #end
    }

    public inline static function div(a:Int, b:Int):Int {
        #if cpp
        return untyped __cpp__('({0}/{1})', a, b);
        #elseif cs
        return untyped __cs__('({0}/{1})', a, b);
        #elseif js
        return js.Syntax.code('({0}/{1})>>0', a, b);
        #else
        return Std.int(a/b);
        #end
    }

    public inline static function blendMultiply(b:Int, s:Int, t:Int):Int {
        t = mul_un8_0(b, s, t);
        return mul_un8_1(t);
    }

    public inline static function blendScreen(b:Int, s:Int, t:Int):Int {
        t = mul_un8_0(b, s, t);
        return b + s - mul_un8_1(t);
    }

    public inline static function blendOverlay(b:Int, s:Int, t:Int):Int {
        return blendHardLight(s, b, t);
    }

    public inline static function blendDarken(b:Int, s:Int):Int {
        return min(b, s);
    }

    public inline static function blendLighten(b:Int, s:Int):Int {
        return max(b, s);
    }

    public inline static function blendHardLight(b:Int, s:Int, t:Int):Int {
        return s < 128 ? blendMultiply(b, (s)<<1, t) : blendScreen(b, ((s)<<1)-255, t);
    }

    public inline static function blendDifference(b:Int, s:Int):Int {
        return abs(b - s);
    }

    public inline static function blendExclusion(b:Int, s:Int, t:Int):Int {
        t = mul_un8_0(b, s, t);
        t = mul_un8_1(t);
        return b + s - 2*t;
    }

    public inline static function blendColorDodge(b:Int, s:Int):Int
    {
        if (b == 0)
            return 0;

        s = (255 - s);
        if (b >= s)
            return 255;
        else
            return div_un8(b, s); // return b / (1-s)
    }

    public inline static function blendColorBurn(b:Int, s:Int):Int
    {
        if (b == 255)
            return 255;

        b = (255 - b);
        if (b >= s)
            return 0;
        else
            return 255 - div_un8(b, s); // return 1 - ((1-b)/s)
    }

    public inline static function blendSoftLight(_b:Int, _s:Int):Int
    {
        var b:Float = _b / 255.0;
        var s:Float = _s / 255.0;
        var r:Float = 0; var d:Float = 0;

        if (b <= 0.25)
            d = ((16*b-12)*b+4)*b;
        else
            d = Math.sqrt(b);

        if (s <= 0.5)
            r = b - (1.0 - 2.0 * s) * b * (1.0 - b);
        else
            r = b + (2.0 * s - 1.0) * (d - b);

        return Std.int(r * 255 + 0.5);
    }

    public inline static function blendDivide(b:Int, s:Int):Int
    {
        if (b == 0)
          return 0;
        else if (b >= s)
          return 255;
        else
          return div_un8(b, s); // return b / s
    }

    // inline static function mul_un8(a:Int, b:Int, t:Int):Int {
    //     #if cpp
    //     t = untyped __cpp__('{0} * (uint16_t)({1}) + 0x80', a, b);
    //     #else
    //     t = a * b + 0x80;
    //     #end
    //     return ((t >> 8) + t) >> 8;
    // }

    inline static function mul_un8_0(a:Int, b:Int, t:Int):Int {
        #if cpp
        t = untyped __cpp__('{0} * (uint16_t)({1}) + 0x80', a, b);
        #else
        t = a * b + 0x80;
        #end
        return t;
    }

    inline static function mul_un8_1(t:Int):Int {
        return ((t >> 8) + t) >> 8;
    }

    inline static function div_un8(a:Int, b:Int):Int {
        #if cpp
        return untyped __cpp__('((uint16_t)({0}) * 0xFF + ({1} / 2)) / {1}', a, b);
        #elseif cs
        return untyped __cs__('({0} * 0xFF + ({1} / 2)) / {1}', a, b);
        #elseif js
        return js.Syntax.code('({0} * 0xFF + (({1} / 2) >> 0)) / {1}', a, b);
        #else
        return Std.int((a * 0xFF + (b / 2)) / b);
        #end
    }

    public inline static function rgba(r:Int, g:Int, b:Int, a:Int):AlphaColor {
        return AlphaColor.fromRGBA(r, g, b, a);
    }

    public inline static function rgbaLuma(c:AlphaColor):Int {
        return rgbLuma(c.red, c.green, c.blue);
    }

    public inline static function rgbLuma(r:Int, g:Int, b:Int):Int {
        #if cpp
        return untyped __cpp__('({0}*2126 + {1}*7152 + {2}*722) / 10000', r, g, b);
        #elseif cs
        return untyped __cs__('({0}*2126 + {1}*7152 + {2}*722) / 10000', r, g, b);
        #elseif js
        return js.Syntax.code('({0}*2126 + {1}*7152 + {2}*722) >> 0', r, g, b);
        #else
        return Std.int((r*2126 + g*7152 + b*722) / 10000);
        #end
    }

    public static function rgbaBlenderSrc(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        return src;
    }

    public static function rgbaBlenderMerge(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var bR:Int = 0; var bG:Int = 0; var bB:Int = 0; var bA:Int = 0;
        var sR:Int = 0; var sG:Int = 0; var sB:Int = 0; var sA:Int = 0;
        var rR:Int = 0; var rG:Int = 0; var rB:Int = 0; var rA:Int = 0;
        var t:Int = 0;

        bR = backdrop.red;
        bG = backdrop.green;
        bB = backdrop.blue;
        bA = backdrop.alpha;

        sR = src.red;
        sG = src.green;
        sB = src.blue;
        sA = src.alpha;

        if (bA == 0) {
          rR = sR;
          rG = sG;
          rB = sB;
        }
        else if (sA == 0) {
          rR = bR;
          rG = bG;
          rB = bB;
        }
        else {
          t = mul_un8_0((sR - bR), opacity, t);
          rR = bR + mul_un8_1(t);
          t = mul_un8_0((sG - bG), opacity, t);
          rG = bG + mul_un8_1(t);
          t = mul_un8_0((sB - bB), opacity, t);
          rB = bB + mul_un8_1(t);
        }
        t = mul_un8_0((sA - bA), opacity, t);
        rA = bA + mul_un8_1(t);
        if (rA == 0)
          rR = rG = rB = 0;

        return rgba(rR, rG, rB, rA);
    }

    public static function rgbaBlenderNegBw(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        if ((backdrop & A_MASK) == 0)
          return rgba(0, 0, 0, 255);
        else if (rgbaLuma(backdrop) < 128)
          return rgba(255, 255, 255, 255);
        else
          return rgba(0, 0, 0, 255);
    }

    public static function rgbaBlenderRedTint(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var v:Int = rgbaLuma(src);
        src = rgba(half(255+v), half(v), half(v), src.alpha);
        return rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderBlueTint(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var v:Int = rgbaLuma(src);
        src = rgba(half(v), half(v), half(255+v), src.alpha);
        return rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderNormal(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var t:Int = 0;
        var result:AlphaColor = AlphaColor.TRANSPARENT;

        if ((backdrop & A_MASK) == 0) {
            var a:Int = src.alpha;
            t = mul_un8_0(a, opacity, t);
            a = mul_un8_1(t);
            a <<= A_SHIFT;
            result = (src & RGB_MASK) | a;
        }
        else if ((src & A_MASK) == 0) {
            result = backdrop;
        }
        else {
            final bR:Int = backdrop.red;
            final bG:Int = backdrop.green;
            final bB:Int = backdrop.blue;
            final bA:Int = backdrop.alpha;

            final sR:Int = src.red;
            final sG:Int = src.green;
            final sB:Int = src.blue;
            var sA:Int = src.alpha;
            t = mul_un8_0(sA, opacity, t);
            sA = mul_un8_1(t);

            // rA = sA + bA*(1-sA)
            //    = sA + bA - bA*sA
            t = mul_un8_0(bA, sA, t);
            final rA:Int = sA + bA - mul_un8_1(t);

            // rA = sA + bA*(1-sA)
            // bA = (rA-sA) / (1-sA)
            // Rc = (Sc*sA + Bc*bA*(1-sA)) / rA                    Replacing bA with (rA-sA) / (1-sA)...
            //    = (Sc*sA + Bc*(rA-sA)/(1-sA)*(1-sA)) / rA
            //    = (Sc*sA + Bc*(rA-sA)) / rA
            //    = Sc*sA/rA + Bc*rA/rA - Bc*sA/rA
            //    = Sc*sA/rA + Bc - Bc*sA/rA
            //    = Bc + (Sc-Bc)*sA/rA
            final rR:Int = bR + div((sR-bR) * sA, rA);
            final rG:Int = bG + div((sG-bG) * sA, rA);
            final rB:Int = bB + div((sB-bB) * sA, rA);

            result = rgba(rR, rG, rB, rA);
        }

        return result;
    }

    public static function rgbaBlenderNormalDstOver(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var t:Int = 0;
        t = mul_un8_0(src.alpha, opacity, t);
        var sA:Int = mul_un8_1(t);
        src = (src & RGB_MASK) | (sA << A_SHIFT);
        return inline rgbaBlenderNormal(src, backdrop, 255);
    }

    public static function rgbaBlenderMultiply(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var t:Int = 0;
        var r:Int = blendMultiply(backdrop.red, src.red, t);
        var g:Int = blendMultiply(backdrop.green, src.green, t);
        var b:Int = blendMultiply(backdrop.blue, src.blue, t);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderScreen(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var t:Int = 0;
        var r:Int = blendScreen(backdrop.red, src.red, t);
        var g:Int = blendScreen(backdrop.green, src.green, t);
        var b:Int = blendScreen(backdrop.blue, src.blue, t);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderOverlay(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var t:Int = 0;
        var r:Int = blendOverlay(backdrop.red, src.red, t);
        var g:Int = blendOverlay(backdrop.green, src.green, t);
        var b:Int = blendOverlay(backdrop.blue, src.blue, t);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderDarken(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Int = blendDarken(backdrop.red, src.red);
        var g:Int = blendDarken(backdrop.green, src.green);
        var b:Int = blendDarken(backdrop.blue, src.blue);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderLighten(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Int = blendLighten(backdrop.red, src.red);
        var g:Int = blendLighten(backdrop.green, src.green);
        var b:Int = blendLighten(backdrop.blue, src.blue);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderColorDodge(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Int = blendColorDodge(backdrop.red, src.red);
        var g:Int = blendColorDodge(backdrop.green, src.green);
        var b:Int = blendColorDodge(backdrop.blue, src.blue);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderColorBurn(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Int = blendColorBurn(backdrop.red, src.red);
        var g:Int = blendColorBurn(backdrop.green, src.green);
        var b:Int = blendColorBurn(backdrop.blue, src.blue);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderHardLight(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var t:Int = 0;
        var r:Int = blendHardLight(backdrop.red, src.red, t);
        var g:Int = blendHardLight(backdrop.green, src.green, t);
        var b:Int = blendHardLight(backdrop.blue, src.blue, t);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderSoftLight(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Int = blendSoftLight(backdrop.red, src.red);
        var g:Int = blendSoftLight(backdrop.green, src.green);
        var b:Int = blendSoftLight(backdrop.blue, src.blue);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderDifference(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Int = blendDifference(backdrop.red, src.red);
        var g:Int = blendDifference(backdrop.green, src.green);
        var b:Int = blendDifference(backdrop.blue, src.blue);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderExclusion(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var t:Int = 0;
        var r:Int = blendExclusion(backdrop.red, src.red, t);
        var g:Int = blendExclusion(backdrop.green, src.green, t);
        var b:Int = blendExclusion(backdrop.blue, src.blue, t);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    //////////////////////////////////////////////////////////////////////
    // HSV blenders

    public inline static function lum(r:Float, g:Float, b:Float):Float
    {
        return 0.3*r + 0.59*g + 0.11*b;
    }

    public inline static function sat(r:Float, g:Float, b:Float):Float
    {
        return Math.max(r, Math.max(g, b)) - Math.min(r, Math.min(g, b));
    }

    public inline static function clipColor():Void /*double& r, double& g, double& b*/
    {
        var l:Float = lum(_float_r, _float_g, _float_b);
        var n:Float = Math.min(_float_r, Math.min(_float_g, _float_b));
        var x:Float = Math.max(_float_r, Math.max(_float_g, _float_b));

        if (n < 0) {
            _float_r = l + (((_float_r - l) * l) / (l - n));
            _float_g = l + (((_float_g - l) * l) / (l - n));
            _float_b = l + (((_float_b - l) * l) / (l - n));
        }

        if (x > 1) {
            _float_r = l + (((_float_r - l) * (1 - l)) / (x - l));
            _float_g = l + (((_float_g - l) * (1 - l)) / (x - l));
            _float_b = l + (((_float_b - l) * (1 - l)) / (x - l));
        }
    }

    public inline static function setLum(l:Float):Void /*double& r, double& g, double& b*/
    {
        var d:Float = l - lum(_float_r, _float_g, _float_b);
        _float_r += d;
        _float_g += d;
        _float_b += d;
        inline clipColor();
    }

    // TODO replace this with a better impl (and test this, not sure if it's correct)
    // Check future changes there: https://github.com/aseprite/aseprite/blob/main/src/doc/blend_funcs.cpp
    static function setSat(s:Float):Void
    {
        inline function _min(x:Float,y:Float) return (((x) < (y)) ? (x) : (y));
        inline function _max(x:Float,y:Float) return (((x) > (y)) ? (x) : (y));
        inline function _mid(x:Float,y:Float,z:Float) return ((x) > (y) ? ((y) > (z) ? (y) : ((x) > (z) ? (z) : (x))) : ((y) > (z) ? ((z) > (x) ? (z) : (x)) : (y)));

        var min:Float = _min(_float_r, _min(_float_g, _float_b));
        var mid:Float = _mid(_float_r, _float_g, _float_b);
        var max:Float = _max(_float_r, _max(_float_g, _float_b));

        if (max > min) {
          mid = ((mid - min)*s) / (max - min);
          max = s;
        }
        else
          mid = max = 0;

        min = 0;
    }

    public static function rgbaBlenderHslHue(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Float = backdrop.red/255.0;
        var g:Float = backdrop.green/255.0;
        var b:Float = backdrop.blue/255.0;
        var s:Float = sat(r, g, b);
        var l:Float = lum(r, g, b);

        r = src.red/255.0;
        g = src.green/255.0;
        b = src.blue/255.0;

        _float_r = r; _float_g = g; _float_b = b;
        inline setSat(s);
        inline setLum(l);
        r = _float_r; g = _float_g; b = _float_b;

        src = rgba(Std.int(255.0*r), Std.int(255.0*g), Std.int(255.0*b), 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderHslSaturation(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Float = src.red/255.0;
        var g:Float = src.green/255.0;
        var b:Float = src.blue/255.0;
        var s:Float = sat(r, g, b);

        r = backdrop.red/255.0;
        g = backdrop.green/255.0;
        b = backdrop.blue/255.0;
        var l:Float = lum(r, g, b);

        _float_r = r; _float_g = g; _float_b = b;
        inline setSat(s);
        inline setLum(l);
        r = _float_r; g = _float_g; b = _float_b;

        src = rgba(Std.int(255.0*r), Std.int(255.0*g), Std.int(255.0*b), 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderHslColor(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Float = backdrop.red/255.0;
        var g:Float = backdrop.green/255.0;
        var b:Float = backdrop.blue/255.0;
        var l:Float = lum(r, g, b);

        r = src.red/255.0;
        g = src.green/255.0;
        b = src.blue/255.0;

        _float_r = r; _float_g = g; _float_b = b;
        inline setLum(l);
        r = _float_r; g = _float_g; b = _float_b;

        src = rgba(Std.int(255.0*r), Std.int(255.0*g), Std.int(255.0*b), 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderHslLuminosity(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Float = src.red/255.0;
        var g:Float = src.green/255.0;
        var b:Float = src.blue/255.0;
        var l:Float = lum(r, g, b);

        r = backdrop.red/255.0;
        g = backdrop.green/255.0;
        b = backdrop.blue/255.0;

        _float_r = r; _float_g = g; _float_b = b;
        inline setLum(l);
        r = _float_r; g = _float_g; b = _float_b;

        src = rgba(Std.int(255.0*r), Std.int(255.0*g), Std.int(255.0*b), 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderAddition(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Int = backdrop.red + src.red;
        var g:Int = backdrop.green + src.green;
        var b:Int = backdrop.blue + src.blue;
        src = rgba(min(r, 255),
                     min(g, 255),
                     min(b, 255), 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderSubtract(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Int = backdrop.red - src.red;
        var g:Int = backdrop.green - src.green;
        var b:Int = backdrop.blue - src.blue;
        src = rgba(max(r, 0), max(g, 0), max(b, 0), 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

    public static function rgbaBlenderDivide(backdrop:AlphaColor, src:AlphaColor, opacity:Int):AlphaColor
    {
        var r:Int = blendDivide(backdrop.red, src.red);
        var g:Int = blendDivide(backdrop.green, src.green);
        var b:Int = blendDivide(backdrop.blue, src.blue);
        src = rgba(r, g, b, 0) | (src & A_MASK);
        return inline rgbaBlenderNormal(backdrop, src, opacity);
    }

}
