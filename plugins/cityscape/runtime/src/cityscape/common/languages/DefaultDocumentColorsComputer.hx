// Ported from vscode src/vs/editor/common/languages/defaultDocumentColorsComputer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.base.common.Color;
import cityscape.base.common.JsValues;
import cityscape.base.common.RegExp;
import cityscape.common.Languages.IColor;
import cityscape.common.Languages.IColorInformation;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range.IRange;

/**
 * What the default colors computer reads: the text, offsets to positions
 * and the matches of a regular expression (Monaco's worker mirror model).
 */
interface IDocumentColorComputerTarget {
    function getValue():String;
    function positionAt(offset:Int):IPosition;
    /**
     * The matches of a global regular expression, line by line, their
     * `index` an offset in the whole text.
     */
    function findMatches(regex:RegExp):Array<ColorMatch>;
}

/**
 * A match of `findMatches` (Monaco's `RegExpMatchArray`): the match and its
 * groups (null for a group that did not match), and its offset.
 */
class ColorMatch {
    public final values:Array<Null<String>>;
    public final index:Int;

    public function new(values:Array<Null<String>>, index:Int) {
        this.values = values;
        this.index = index;
    }

    /**
     * `String.prototype.matchAll(regex)`: the matches of a global
     * expression, their index offset by `offset`.
     */
    public static function matchAll(text:String, regex:RegExp, offset:Int, result:Array<ColorMatch>):Void {
        regex.lastIndex = 0;
        while (true) {
            final m = regex.exec(text);
            if (m == null) {
                break;
            }
            result.push(new ColorMatch([for (i in 0...m.length) m[i]], m.index + offset));
            if (m[0].length == 0) {
                regex.lastIndex = regex.lastIndex + 1;
            }
        }
    }
}

/**
 * The colors of a text model with the default colors computer (Monaco's
 * mirror model: offsets with the model's end of line).
 */
class TextModelDocumentColorComputerTarget implements IDocumentColorComputerTarget {

    final model:ITextModel;

    public function new(model:ITextModel) {
        this.model = model;
    }

    public function getValue():String {
        return model.getValue();
    }

    public function positionAt(offset:Int):IPosition {
        final position = model.getPositionAt(offset);
        return {lineNumber: position.lineNumber, column: position.column};
    }

    public function findMatches(regex:RegExp):Array<ColorMatch> {
        final matches:Array<ColorMatch> = [];
        for (i in 0...model.getLineCount()) {
            final line = model.getLineContent(i + 1);
            final offsetToAdd = model.getOffsetAt(new Position(i + 1, 1));
            ColorMatch.matchAll(line, regex, offsetToAdd, matches);
        }
        return matches;
    }

}

/**
 * The module functions of defaultDocumentColorsComputer.ts.
 */
class DefaultDocumentColorsComputer {

    static function _parseCaptureGroups(captureGroups:Array<Null<String>>):Array<Float> {
        final values:Array<Float> = [];
        for (captureGroup in captureGroups) {
            if (captureGroup == null) {
                // `Number(undefined)` is NaN
                continue;
            }
            final parsedNumber = JsValues.toNumber(captureGroup);
            if ((parsedNumber != 0 && !Math.isNaN(parsedNumber)) || parsedNumber == 0 && removeWhiteSpace(captureGroup) != '') {
                values.push(parsedNumber);
            }
        }
        return values;
    }

    /**
     * `value.replace(/\s/g, '')`.
     */
    static function removeWhiteSpace(value:String):String {
        final buf = new StringBuf();
        for (i in 0...value.length) {
            final c = StringTools.fastCodeAt(value, i);
            final isSpace = switch c {
                case 0x09 | 0x0a | 0x0b | 0x0c | 0x0d | 0x20 | 0xa0 | 0x1680 | 0x2028 | 0x2029 | 0x202f | 0x205f | 0x3000 | 0xfeff: true;
                case _: c >= 0x2000 && c <= 0x200a;
            }
            if (!isSpace) {
                buf.addChar(c);
            }
        }
        return buf.toString();
    }

    static function _toIColor(r:Float, g:Float, b:Float, a:Float):IColor {
        return {
            red: r / 255,
            blue: b / 255,
            green: g / 255,
            alpha: a
        };
    }

    static function _findRange(model:IDocumentColorComputerTarget, match:ColorMatch):Null<IRange> {
        final index = match.index;
        final length = match.values[0].length;
        if (index == 0) {
            // Monaco's `if (!index)`: a color at the start of the text is skipped
            return null;
        }
        final startPosition = model.positionAt(index);
        final range:IRange = {
            startLineNumber: startPosition.lineNumber,
            startColumn: startPosition.column,
            endLineNumber: startPosition.lineNumber,
            endColumn: startPosition.column + length
        };
        return range;
    }

    static function _findHexColorInformation(range:Null<IRange>, hexValue:String):Null<IColorInformation> {
        if (range == null) {
            return null;
        }
        final parsedHexColor = ColorFormatCSS.parseHex(hexValue);
        if (parsedHexColor == null) {
            return null;
        }
        return {
            range: range,
            color: _toIColor(parsedHexColor.rgba.r, parsedHexColor.rgba.g, parsedHexColor.rgba.b, parsedHexColor.rgba.a)
        };
    }

    static function _findRGBColorInformation(range:Null<IRange>, matches:Array<ColorMatch>, isAlpha:Bool):Null<IColorInformation> {
        if (range == null || matches.length != 1) {
            return null;
        }
        final match = matches[0];
        final parsedRegex = _parseCaptureGroups(match.values);
        return {
            range: range,
            color: _toIColor(parsedRegex[0], parsedRegex[1], parsedRegex[2], isAlpha ? parsedRegex[3] : 1)
        };
    }

    static function _findHSLColorInformation(range:Null<IRange>, matches:Array<ColorMatch>, isAlpha:Bool):Null<IColorInformation> {
        if (range == null || matches.length != 1) {
            return null;
        }
        final match = matches[0];
        final parsedRegex = _parseCaptureGroups(match.values);
        final colorEquivalent = new Color(new HSLA(parsedRegex[0], parsedRegex[1] / 100, parsedRegex[2] / 100, isAlpha ? parsedRegex[3] : 1));
        return {
            range: range,
            color: _toIColor(colorEquivalent.rgba.r, colorEquivalent.rgba.g, colorEquivalent.rgba.b, colorEquivalent.rgba.a)
        };
    }

    static function _findMatchesInString(model:String, regex:RegExp):Array<ColorMatch> {
        final result:Array<ColorMatch> = [];
        ColorMatch.matchAll(model, regex, 0, result);
        return result;
    }

    // The expressions are compiled on first use (statics are immutable data)
    static var _initialValidationRegex:Null<RegExp> = null;
    static var _rgbRegex:Null<RegExp> = null;
    static var _rgbaRegex:Null<RegExp> = null;
    static var _hslRegex:Null<RegExp> = null;
    static var _hslaRegex:Null<RegExp> = null;

    static inline final BYTE = "(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])";
    static inline final ALPHA = "(0[.][0-9]+|[.][0-9]+|[01][.]|[01])";
    static inline final HUE = "(36[0]|3[0-5][0-9]|[12][0-9][0-9]|[1-9]?[0-9])";
    static inline final PERCENT = "(100|\\d{1,2}[.]\\d*|\\d{1,2})%";

    static function computeColors(model:IDocumentColorComputerTarget):Array<IColorInformation> {
        final result:Array<IColorInformation> = [];
        // Early validation for RGB and HSL
        if (_initialValidationRegex == null) {
            _initialValidationRegex = new RegExp("\\b(rgb|rgba|hsl|hsla)(\\([0-9\\s,.\\%]*\\))|(#)([A-Fa-f0-9]{3})\\b|(#)([A-Fa-f0-9]{4})\\b|(#)([A-Fa-f0-9]{6})\\b|(#)([A-Fa-f0-9]{8})\\b", 'gm');
            _rgbRegex = new RegExp("^\\(\\s*" + BYTE + "\\s*,\\s*" + BYTE + "\\s*,\\s*" + BYTE + "\\s*\\)$", 'gm');
            _rgbaRegex = new RegExp("^\\(\\s*" + BYTE + "\\s*,\\s*" + BYTE + "\\s*,\\s*" + BYTE + "\\s*,\\s*" + ALPHA + "\\s*\\)$", 'gm');
            _hslRegex = new RegExp("^\\(\\s*" + HUE + "\\s*,\\s*" + PERCENT + "\\s*,\\s*" + PERCENT + "\\s*\\)$", 'gm');
            _hslaRegex = new RegExp("^\\(\\s*" + HUE + "\\s*,\\s*" + PERCENT + "\\s*,\\s*" + PERCENT + "\\s*,\\s*" + ALPHA + "\\s*\\)$", 'gm');
        }
        final initialValidationMatches = model.findMatches(_initialValidationRegex);

        // Potential colors have been found, validate the parameters
        if (initialValidationMatches.length > 0) {
            for (initialMatch in initialValidationMatches) {
                final initialCaptureGroups = [for (captureGroup in initialMatch.values) if (captureGroup != null) captureGroup];
                final colorScheme = initialCaptureGroups[1];
                final colorParameters = initialCaptureGroups[2];
                if (colorParameters == null || colorParameters.length == 0) {
                    continue;
                }
                var colorInformation:Null<IColorInformation> = null;
                if (colorScheme == 'rgb') {
                    colorInformation = _findRGBColorInformation(_findRange(model, initialMatch), _findMatchesInString(colorParameters, _rgbRegex), false);
                }
                else if (colorScheme == 'rgba') {
                    colorInformation = _findRGBColorInformation(_findRange(model, initialMatch), _findMatchesInString(colorParameters, _rgbaRegex), true);
                }
                else if (colorScheme == 'hsl') {
                    colorInformation = _findHSLColorInformation(_findRange(model, initialMatch), _findMatchesInString(colorParameters, _hslRegex), false);
                }
                else if (colorScheme == 'hsla') {
                    colorInformation = _findHSLColorInformation(_findRange(model, initialMatch), _findMatchesInString(colorParameters, _hslaRegex), true);
                }
                else if (colorScheme == '#') {
                    colorInformation = _findHexColorInformation(_findRange(model, initialMatch), colorScheme + colorParameters);
                }
                if (colorInformation != null) {
                    result.push(colorInformation);
                }
            }
        }
        return result;
    }

    /**
     * Returns an array of all default document colors in the provided document
     */
    public static function computeDefaultDocumentColors(model:Null<IDocumentColorComputerTarget>):Array<IColorInformation> {
        if (model == null) {
            // Unknown caller!
            return [];
        }
        return computeColors(model);
    }

}
