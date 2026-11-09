// Ported from vscode src/vs/editor/common/config/fontInfo.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

/**
 * The font settings of an editor.
 *
 * TODO(step 2): only the fields so far. `createFromValidatedSettings`,
 * `getId`, `getMassagedFontFamily` and the measurement of `FontInfo`
 * (done by Glaze's text system instead of the DOM) come with the view.
 */
class BareFontInfo {

    public final pixelRatio:Float;

    public final fontFamily:String;

    public final fontWeight:String;

    public final fontSize:Float;

    public final fontFeatureSettings:String;

    public final fontVariationSettings:String;

    public final lineHeight:Int;

    public final letterSpacing:Float;

    function new(opts:{
        pixelRatio:Float,
        fontFamily:String,
        fontWeight:String,
        fontSize:Float,
        fontFeatureSettings:String,
        fontVariationSettings:String,
        lineHeight:Float,
        letterSpacing:Float
    }) {
        this.pixelRatio = opts.pixelRatio;
        this.fontFamily = opts.fontFamily;
        this.fontWeight = opts.fontWeight;
        this.fontSize = opts.fontSize;
        this.fontFeatureSettings = opts.fontFeatureSettings;
        this.fontVariationSettings = opts.fontVariationSettings;
        this.lineHeight = Std.int(opts.lineHeight);
        this.letterSpacing = opts.letterSpacing;
    }

}

class FontInfo extends BareFontInfo {

    public final isTrusted:Bool;

    public final isMonospace:Bool;

    public final typicalHalfwidthCharacterWidth:Float;

    public final typicalFullwidthCharacterWidth:Float;

    public final canUseHalfwidthRightwardsArrow:Bool;

    public final spaceWidth:Float;

    public final middotWidth:Float;

    public final wsmiddotWidth:Float;

    public final maxDigitWidth:Float;

    /**
     * @internal
     */
    public function new(opts:{
        pixelRatio:Float,
        fontFamily:String,
        fontWeight:String,
        fontSize:Float,
        fontFeatureSettings:String,
        fontVariationSettings:String,
        lineHeight:Float,
        letterSpacing:Float,
        isMonospace:Bool,
        typicalHalfwidthCharacterWidth:Float,
        typicalFullwidthCharacterWidth:Float,
        canUseHalfwidthRightwardsArrow:Bool,
        spaceWidth:Float,
        middotWidth:Float,
        wsmiddotWidth:Float,
        maxDigitWidth:Float
    }, isTrusted:Bool) {
        super({
            pixelRatio: opts.pixelRatio,
            fontFamily: opts.fontFamily,
            fontWeight: opts.fontWeight,
            fontSize: opts.fontSize,
            fontFeatureSettings: opts.fontFeatureSettings,
            fontVariationSettings: opts.fontVariationSettings,
            lineHeight: opts.lineHeight,
            letterSpacing: opts.letterSpacing
        });
        this.isTrusted = isTrusted;
        this.isMonospace = opts.isMonospace;
        this.typicalHalfwidthCharacterWidth = opts.typicalHalfwidthCharacterWidth;
        this.typicalFullwidthCharacterWidth = opts.typicalFullwidthCharacterWidth;
        this.canUseHalfwidthRightwardsArrow = opts.canUseHalfwidthRightwardsArrow;
        this.spaceWidth = opts.spaceWidth;
        this.middotWidth = opts.middotWidth;
        this.wsmiddotWidth = opts.wsmiddotWidth;
        this.maxDigitWidth = opts.maxDigitWidth;
    }

    /**
     * @internal
     */
    public function equals(other:FontInfo):Bool {
        return (
            this.fontFamily == other.fontFamily
            && this.fontWeight == other.fontWeight
            && this.fontSize == other.fontSize
            && this.fontFeatureSettings == other.fontFeatureSettings
            && this.fontVariationSettings == other.fontVariationSettings
            && this.lineHeight == other.lineHeight
            && this.letterSpacing == other.letterSpacing
            && this.typicalHalfwidthCharacterWidth == other.typicalHalfwidthCharacterWidth
            && this.typicalFullwidthCharacterWidth == other.typicalFullwidthCharacterWidth
            && this.canUseHalfwidthRightwardsArrow == other.canUseHalfwidthRightwardsArrow
            && this.spaceWidth == other.spaceWidth
            && this.middotWidth == other.middotWidth
            && this.wsmiddotWidth == other.wsmiddotWidth
            && this.maxDigitWidth == other.maxDigitWidth
        );
    }

}
