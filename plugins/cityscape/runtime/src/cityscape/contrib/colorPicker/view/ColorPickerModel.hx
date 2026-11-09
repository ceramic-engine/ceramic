// Ported from vscode src/vs/editor/contrib/colorPicker/browser/colorPickerModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.colorPicker.view;

import cityscape.base.common.Color;
import cityscape.base.common.Event;
import cityscape.common.Languages.IColorPresentation;

/**
 * The state of a color picker: the original color, the picked one, the
 * presentations of the picked color and the one shown.
 */
class ColorPickerModel {

    public final originalColor:Color;
    var _color:Color;

    public var color(get, set):Color;
    function get_color():Color {
        return this._color;
    }
    function set_color(color:Color):Color {
        if (this._color.equals(color)) {
            return color;
        }

        this._color = color;
        this._onDidChangeColor.fire(color);
        return color;
    }

    public var presentation(get, never):Null<IColorPresentation>;
    function get_presentation():Null<IColorPresentation> {
        return this.presentationIndex < this.colorPresentations.length ? this.colorPresentations[this.presentationIndex] : null;
    }

    var _colorPresentations:Array<IColorPresentation>;

    public var colorPresentations(get, set):Array<IColorPresentation>;
    function get_colorPresentations():Array<IColorPresentation> {
        return this._colorPresentations;
    }
    function set_colorPresentations(colorPresentations:Array<IColorPresentation>):Array<IColorPresentation> {
        this._colorPresentations = colorPresentations;
        if (this.presentationIndex > colorPresentations.length - 1) {
            this.presentationIndex = 0;
        }
        this._onDidChangePresentation.fire(this.presentation);
        return colorPresentations;
    }

    final _onColorFlushed = new Emitter<Color>();
    public final onColorFlushed:Event<Color>;

    final _onDidChangeColor = new Emitter<Color>();
    public final onDidChangeColor:Event<Color>;

    final _onDidChangePresentation = new Emitter<Null<IColorPresentation>>();
    public final onDidChangePresentation:Event<Null<IColorPresentation>>;

    var presentationIndex:Int;

    public function new(color:Color, availableColorPresentations:Array<IColorPresentation>, presentationIndex:Int) {
        this.originalColor = color;
        this._color = color;
        this._colorPresentations = availableColorPresentations;
        this.presentationIndex = presentationIndex;
        this.onColorFlushed = _onColorFlushed.event;
        this.onDidChangeColor = _onDidChangeColor.event;
        this.onDidChangePresentation = _onDidChangePresentation.event;
    }

    public function selectNextColorPresentation():Void {
        if (this.colorPresentations.length == 0) {
            // `% 0` is NaN in Monaco: no presentation
            return;
        }
        this.presentationIndex = (this.presentationIndex + 1) % this.colorPresentations.length;
        this.flushColor();
        this._onDidChangePresentation.fire(this.presentation);
    }

    public function guessColorPresentation(color:Color, originalText:String):Void {
        var presentationIndex = -1;
        for (i in 0...this.colorPresentations.length) {
            if (originalText.toLowerCase() == this.colorPresentations[i].label) {
                presentationIndex = i;
                break;
            }
        }

        if (presentationIndex == -1) {
            // check which color presentation text has same prefix as original text's prefix
            final originalTextPrefix = originalText.split('(')[0].toLowerCase();
            for (i in 0...this.colorPresentations.length) {
                if (StringTools.startsWith(this.colorPresentations[i].label.toLowerCase(), originalTextPrefix)) {
                    presentationIndex = i;
                    break;
                }
            }
        }

        if (presentationIndex != -1 && presentationIndex != this.presentationIndex) {
            this.presentationIndex = presentationIndex;
            this._onDidChangePresentation.fire(this.presentation);
        }
    }

    public function flushColor():Void {
        this._onColorFlushed.fire(this._color);
    }

    public function dispose():Void {
        _onColorFlushed.dispose();
        _onDidChangeColor.dispose();
        _onDidChangePresentation.dispose();
    }
}
