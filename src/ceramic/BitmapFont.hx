package ceramic;

// Substantial portion taken from luxe (https://github.com/underscorediscovery/luxe/blob/4c891772f54b4769c72515146bedde9206a7b986/phoenix/BitmapFont.hx)

import ceramic.internal.BitmapFontData;
import ceramic.internal.BitmapFontParser;

using unifill.Unifill;

class BitmapFont {

    /** The map of font texture pages to their id. */
    public var pages:Map<Int,Texture> = new Map();

    /** The bitmap font data */
    public var data(default, set):BitmapFontData;
    function set_data(data:BitmapFontData) {

        this.data = data;

        if (data != null) {
            spaceChar = data.chars.get(32);
        }

        return data;

    } //data

    /** Cached reference of the ' '(32) character, for sizing on tabs/spaces */
    public var spaceChar:Character;

    public function new(data:BitmapFontData, pages:Map<String,Texture>) {

        if (data == null) {
            throw 'BitmapFont: data is null';
        }
        if (pages == null) {
            throw 'BitmapFont: pages is null';
        }

        for (pageInfo in data.pages) {
            var texture = pages.get(pageInfo.file);
            if (texture == null) {
                throw 'BitmapFont: missing texture for file ' + pageInfo.file;
            }
            this.pages.set(pageInfo.id, texture);
        }

    } //new

/// Public API

    /** Returns the kerning between two glyphs, or 0 if none.
        A glyph int id is the value from 'c'.charCodeAt(0) */
    public inline function kerning(first:Int, second:Int) {

        var map = data.kernings.get(first);

        if (map != null && map.exists(second)) {
            return map.get(second);
        }

        return 0;

    } //kerning

    /** Wrap the given string to the given width, using the given metrics.
        Returns a new array, with each line of the string split across the bounds. */
    public function wrapStringToWidth(string:String, width:Float, pointSize:Float, letterSpacing:Float=0.0):String {

        if (width <= 0) {
            return string;
        }

        var curX = 0.0; var idx = 0;
        var finalStr = '';

        inline function _wordw(str:String) {
            return widthOf(str, pointSize, letterSpacing);
        }

        var spaceW = _wordw(' ');

        inline function _dowrap(w:Float, str:String) {
            if (curX + w > width) {
                curX = 0;
                finalStr += '\n';
            }

            curX += w;
            finalStr += str;
        } //_dowrap

        var strings = string.split(' ');
        var count = strings.length;

        for (str in strings) {
            if (str.uIndexOf('\n') == -1) {
                if (str == '') str = ' ';
                _dowrap( _wordw(str), str );
            } else {
                var widx = 0;
                var words = str.split('\n');
                for (word in words) {

                    if (word != '') {
                        _dowrap( _wordw(word), word );
                    } else {
                        curX = 0;
                    }

                    if (widx < words.length-1) {
                        finalStr += '\n';
                        curX = 0;
                    }

                    widx++;

                } //each word
            } //no spaces

            if (idx < count-1) {
                finalStr += ' ';
                curX += spaceW + letterSpacing;
            }

            idx++;

        } //each word

        return finalStr;

    } //wrapStringToWidth

    /** Returns the width of the given line, which assumes the line is already split up (does not split the string), using the given metrics. */
    public function widthOfLine(string:String, pointSize:Float=1.0, letterSpacing:Float=0.0) {

        // Current x pos
        var curX = 0.0;
        // Current w pos
        var curW = 0.0;
        // The size ratio between font and given size
        var ratio = pointSize / data.pointSize;

        var i = 0;
        var len = string.uLength();

        for (uglyph in string.uIterator()) {

            var index = uglyph.toInt();
            var char = data.chars.get(index);
            if (char == null) char = spaceChar;

            // Some characters (like spaces) have no width but an advance
            // which is relevant/needed
            var cw = (char.xOffset + Math.max(char.width, char.xAdvance)) * ratio;
            var cx = curX + (char.xOffset * ratio);

            var spacing = char.xAdvance;
            if (i < len-1) {
                var nextIndex = string.uCharCodeAt(i+1);
                spacing += kerning( index, nextIndex );
                if (nextIndex >= 32) { spacing += letterSpacing; }
            }

            curX += spacing * ratio;
            curW = Math.max(curW, cx+cw);

            ++i;
        } //each char

        return curW;

    } //widthOfLine

    /** Returns the width of the given string, using the given metrics.
        This will split the string and populate the optional lineWidths array with each line width of the string */
    public inline function widthOf(string:String, pointSize:Float = 1.0, letterSpacing:Float = 0.0, ?lineWidths:Array<Float>):Float {

        // If given an array to cache line widths into
        var maxW = 0.0;
        var pushWidths = (lineWidths != null);
        var lines = string.uSplit('\n');

        for (line in lines) {

            var curW = widthOfLine(line, pointSize, letterSpacing);

            maxW = Math.max( maxW, curW );

            if (pushWidths) {
                lineWidths.push(curW);
            }

        } //each line

        // Return the max width found
        return maxW;

    } //widthOf

    /** Returns the height of a string, using the given metrics. */
    public inline function heightOf(string:String, pointSize:Float, lineSpacing:Float=0.0):Float {

        return heightOfLines(string.split('\n'), pointSize, lineSpacing);

    } //heightOf

    /** Get the height of the given lines with the given metrics. */
    public inline function heightOfLines(lines:Array<String>, pointSize:Float, lineSpacing:Float=0.0):Float {

        var ratio = pointSize / data.pointSize;

        return lines.length * ((data.lineHeight + lineSpacing) * ratio);

    } //heightOf

    /** Return the point size at which a line of text will occupy a given pixel height. */
    public inline function lineHeightToPointSize(pixelHeight:Float, lineSpacing:Float=0.0):Float {

        return pixelHeight * ( data.pointSize / ( data.lineHeight + lineSpacing ) );

    } //lineHeightToPointSize


} //BitmapFont
