// Ported from vscode src/vs/editor/common/model/pieceTreeTextBuffer/pieceTreeTextBufferBuilder.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.pieceTreeTextBuffer;

import cityscape.base.common.CharCode;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Strings;
import cityscape.common.Model;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeBase.StringBuffer;

class PieceTreeTextBufferFactory implements ITextBufferFactory {

    final _chunks:Array<StringBuffer>;
    final _bom:String;
    final _cr:Int;
    final _lf:Int;
    final _crlf:Int;
    final _containsRTL:Bool;
    final _containsUnusualLineTerminators:Bool;
    final _isBasicASCII:Bool;
    final _normalizeEOL:Bool;

    public function new(_chunks:Array<StringBuffer>, _bom:String, _cr:Int, _lf:Int, _crlf:Int, _containsRTL:Bool, _containsUnusualLineTerminators:Bool, _isBasicASCII:Bool, _normalizeEOL:Bool) {
        this._chunks = _chunks;
        this._bom = _bom;
        this._cr = _cr;
        this._lf = _lf;
        this._crlf = _crlf;
        this._containsRTL = _containsRTL;
        this._containsUnusualLineTerminators = _containsUnusualLineTerminators;
        this._isBasicASCII = _isBasicASCII;
        this._normalizeEOL = _normalizeEOL;
    }

    function _getEOL(defaultEOL:DefaultEndOfLine):String {
        final totalEOLCount = this._cr + this._lf + this._crlf;
        final totalCRCount = this._cr + this._crlf;
        if (totalEOLCount == 0) {
            // This is an empty file or a file with precisely one line
            return (defaultEOL == DefaultEndOfLine.LF ? '\n' : '\r\n');
        }
        if (totalCRCount > totalEOLCount / 2) {
            // More than half of the file contains \r\n ending lines
            return '\r\n';
        }
        // At least one line more ends in \n
        return '\n';
    }

    public function create(defaultEOL:DefaultEndOfLine):{textBuffer:ITextBuffer, disposable:IDisposable} {
        final eol = this._getEOL(defaultEOL);
        final chunks = this._chunks;

        if (this._normalizeEOL
            && ((eol == '\r\n' && (this._cr > 0 || this._lf > 0))
                || (eol == '\n' && (this._cr > 0 || this._crlf > 0)))
        ) {
            // Normalize pieces
            for (i in 0...chunks.length) {
                final str = Strings.replaceLineBreaks(chunks[i].buffer, eol);
                final newLineStart = PieceTreeBase.createLineStartsFast(str);
                chunks[i] = new StringBuffer(str, newLineStart);
            }
        }

        final textBuffer = new PieceTreeTextBuffer(chunks, this._bom, eol, this._containsRTL, this._containsUnusualLineTerminators, this._isBasicASCII, this._normalizeEOL);
        return {textBuffer: textBuffer, disposable: textBuffer};
    }

    public function getFirstLineText(lengthLimit:Int):String {
        return Strings.splitLines(this._chunks[0].buffer.substr(0, lengthLimit))[0];
    }

}

class PieceTreeTextBufferBuilder implements ITextBufferBuilder {

    final chunks:Array<StringBuffer>;
    var BOM:String;

    var _hasPreviousChar:Bool;
    var _previousChar:Int;
    final _tmpLineStarts:Array<Int>;

    var cr:Int;
    var lf:Int;
    var crlf:Int;
    var containsRTL:Bool;
    var containsUnusualLineTerminators:Bool;
    var isBasicASCII:Bool;

    public function new() {
        this.chunks = [];
        this.BOM = '';

        this._hasPreviousChar = false;
        this._previousChar = 0;
        this._tmpLineStarts = [];

        this.cr = 0;
        this.lf = 0;
        this.crlf = 0;
        this.containsRTL = false;
        this.containsUnusualLineTerminators = false;
        this.isBasicASCII = true;
    }

    public function acceptChunk(chunk:String):Void {
        if (chunk.length == 0) {
            return;
        }

        if (this.chunks.length == 0) {
            if (Strings.startsWithUTF8BOM(chunk)) {
                this.BOM = Strings.UTF8_BOM_CHARACTER;
                chunk = chunk.substr(1);
            }
        }

        // `charCodeAt(-1)` is NaN in JavaScript when the chunk was only a BOM
        final lastChar = chunk.length > 0 ? StringTools.fastCodeAt(chunk, chunk.length - 1) : -1;
        if (lastChar == CharCode.CarriageReturn || (lastChar >= 0xD800 && lastChar <= 0xDBFF)) {
            // last character is \r or a high surrogate => keep it back
            this._acceptChunk1(chunk.substr(0, chunk.length - 1), false);
            this._hasPreviousChar = true;
            this._previousChar = lastChar;
        }
        else {
            this._acceptChunk1(chunk, false);
            this._hasPreviousChar = false;
            this._previousChar = lastChar;
        }
    }

    function _acceptChunk1(chunk:String, allowEmptyStrings:Bool):Void {
        if (!allowEmptyStrings && chunk.length == 0) {
            // Nothing to do
            return;
        }

        if (this._hasPreviousChar) {
            this._acceptChunk2(String.fromCharCode(this._previousChar) + chunk);
        }
        else {
            this._acceptChunk2(chunk);
        }
    }

    function _acceptChunk2(chunk:String):Void {
        final lineStarts = PieceTreeBase.createLineStarts(this._tmpLineStarts, chunk);

        this.chunks.push(new StringBuffer(chunk, lineStarts.lineStarts));
        this.cr += lineStarts.cr;
        this.lf += lineStarts.lf;
        this.crlf += lineStarts.crlf;

        if (!lineStarts.isBasicASCII) {
            // this chunk contains non basic ASCII characters
            this.isBasicASCII = false;
            if (!this.containsRTL) {
                this.containsRTL = Strings.containsRTL(chunk);
            }
            if (!this.containsUnusualLineTerminators) {
                this.containsUnusualLineTerminators = Strings.containsUnusualLineTerminators(chunk);
            }
        }
    }

    public function finish():ITextBufferFactory {
        return finishWithNormalizeEOL(true);
    }

    /**
     * Monaco's `finish(normalizeEOL)` (the interface's `finish()` normalizes).
     */
    public function finishWithNormalizeEOL(normalizeEOL:Bool = true):PieceTreeTextBufferFactory {
        this._finish();
        return new PieceTreeTextBufferFactory(
            this.chunks,
            this.BOM,
            this.cr,
            this.lf,
            this.crlf,
            this.containsRTL,
            this.containsUnusualLineTerminators,
            this.isBasicASCII,
            normalizeEOL
        );
    }

    function _finish():Void {
        if (this.chunks.length == 0) {
            this._acceptChunk1('', true);
        }

        if (this._hasPreviousChar) {
            this._hasPreviousChar = false;
            // recreate last chunk
            final lastChunk = this.chunks[this.chunks.length - 1];
            lastChunk.buffer += String.fromCharCode(this._previousChar);
            final newLineStarts = PieceTreeBase.createLineStartsFast(lastChunk.buffer);
            lastChunk.lineStarts = newLineStarts;
            if (this._previousChar == CharCode.CarriageReturn) {
                this.cr++;
            }
        }
    }

}
