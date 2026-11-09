// New code for Cityscape (not a port): the rendering sink of Monaco's
// `renderViewLine` for Glaze (Monaco writes HTML spans; this keeps the text
// of each span and its class names).
package cityscape.view;

import cityscape.common.viewLayout.LinePart;
import cityscape.common.viewLayout.ViewLineRenderer;

/**
 * The text of a rendered view line and its parts: `text` holds the
 * characters Monaco puts in the line's spans (tabs as non breaking spaces,
 * whitespace as middots or arrows when rendered, control pictures), and
 * part `i` covers `text[partStarts[i], partEnds[i])` with `partClassNames[i]`.
 */
class ViewLineRuns implements IRenderLineSink {

    final _buf:StringBuf;
    var _length:Int = 0;
    var _pendingHigh:Int = -1;

    public var text(default, null):String = '';

    public final partStarts:Array<Int> = [];
    public final partEnds:Array<Int> = [];
    public final partClassNames:Array<String> = [];
    public final partIsWhitespace:Array<Bool> = [];
    /**
     * For each part: the index of the Monaco part (the `DomPosition`
     * part index of the character mapping).
     */
    public final partIndices:Array<Int> = [];

    var _currentPart:Int = -1;

    public function new() {
        _buf = new StringBuf();
    }

    public function beginLine(containsRTL:Bool):Void {}

    public function beginPart(partIndex:Int, part:LinePart, className:String, partContainsRTL:Bool, whitespaceWidth:Float):Void {
        partIndices.push(partIndex);
        partStarts.push(_length);
        partEnds.push(_length);
        partClassNames.push(className);
        partIsWhitespace.push(part.isWhitespace() || className == 'mtkz');
        _currentPart = partStarts.length - 1;
    }

    function addUnit(charCode:Int):Void {
        // UTF-16 units: surrogates are combined into code points for StringBuf
        if (_pendingHigh != -1) {
            if (charCode >= 0xDC00 && charCode <= 0xDFFF) {
                _buf.addChar(((_pendingHigh - 0xD800) << 10) + (charCode - 0xDC00) + 0x10000);
                _pendingHigh = -1;
                _length++;
                return;
            }
            _buf.addChar(0xFFFD);
            _pendingHigh = -1;
        }
        if (charCode >= 0xD800 && charCode <= 0xDBFF) {
            _pendingHigh = charCode;
            _length++;
            return;
        }
        if (charCode >= 0xDC00 && charCode <= 0xDFFF) {
            _buf.addChar(0xFFFD);
            _length++;
            return;
        }
        _buf.addChar(charCode);
        _length++;
    }

    public function appendCharCode(charCode:Int):Void {
        if (charCode == 0xA0) {
            // non breaking spaces are spaces for the shaper
            addUnit(' '.code);
            return;
        }
        if (charCode == 0x200C) {
            // the zero width non joiner after a middot: kept as a unit so
            // that offsets match Monaco's character mapping
            addUnit(0x200C);
            return;
        }
        addUnit(charCode);
    }

    public function appendEscapedCharCode(charCode:Int, html:String):Void {
        addUnit(charCode);
    }

    public function appendNul():Void {
        // Monaco writes `&#00;` (one character in the DOM)
        addUnit(0xFFFD);
    }

    public function appendString(text:String):Void {
        for (i in 0...text.length) {
            addUnit(StringTools.fastCodeAt(text, i));
        }
    }

    public function endPart():Void {
        if (_currentPart >= 0) {
            partEnds[_currentPart] = _length;
        }
        _currentPart = -1;
    }

    public function appendOverflow(text:String):Void {
        // The "Show more" of overflowing lines is not shown (no DOM link)
    }

    public function endLine():Void {
        if (_pendingHigh != -1) {
            _buf.addChar(0xFFFD);
            _pendingHigh = -1;
        }
        text = _buf.toString();
    }

    /**
     * The offset in `text` of a Monaco `DomPosition`.
     */
    public function renderedOffsetOf(domPartIndex:Int, charIndex:Int):Int {
        for (i in 0...partIndices.length) {
            if (partIndices[i] == domPartIndex) {
                final o = partStarts[i] + charIndex;
                return o > partEnds[i] ? partEnds[i] : o;
            }
        }
        return _length;
    }

    /**
     * The part holding rendered offset `offset` (the last one at the end).
     */
    public function partAt(offset:Int):Int {
        for (i in 0...partStarts.length) {
            if (offset < partEnds[i]) {
                return i;
            }
        }
        return partStarts.length - 1;
    }

}
