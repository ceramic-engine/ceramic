// Ported from vscode src/vs/editor/contrib/colorPicker/browser/colorHoverParticipant.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.colorPicker.view;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Color;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.common.Languages.DocumentColorProvider;
import cityscape.common.Languages.IColorInformation;
import cityscape.common.Model;
import cityscape.common.core.Range;
import cityscape.contrib.colorPicker.view.Color.ColorUtils;
import cityscape.view.EditorBrowser;

/**
 * A color with its picker model (Monaco's `ColorHover`, and
 * `StandaloneColorPickerHover` with `standalone`).
 */
class ColorHover {

    /**
     * Force the hover to always be rendered at this specific range,
     * even in the case of multiple hover parts.
     */
    public final forceShowAtRange:Bool = true;

    public final range:Range;
    public final model:ColorPickerModel;
    public final provider:DocumentColorProvider;

    public function new(range:Range, model:ColorPickerModel, provider:DocumentColorProvider) {
        this.range = range;
        this.model = model;
        this.provider = provider;
    }
}

/**
 * What Monaco's color hover participant does once its part shows
 * (`renderHoverParts`): the presentations follow the picked color, a
 * flushed color is written to the model, and an edit made elsewhere hides
 * the picker. The color picker is not a part of the content hover here: the
 * `ColorContribution` shows it in a popover of its own (see DEVIATIONS.md).
 */
class ColorPickerSession implements IDisposable {

    final disposables = new DisposableStore();
    public final colorHover:ColorHover;
    final editor:ICodeEditor;
    var editorUpdatedByColorPicker = false;
    var range:Range;
    final standalone:Bool;

    /**
     * The color of a standalone picker (Monaco's
     * `StandaloneColorPickerParticipant.color`), written by `updateEditorModel`.
     */
    public var color(default, null):Null<cityscape.base.common.Color> = null;

    /**
     * `hide` is called when the model changes from elsewhere (Monaco's
     * `context.hide()` then `editor.focus()`).
     */
    public function new(editor:ICodeEditor, colorHover:ColorHover, hide:() -> Void, standalone:Bool = false) {
        this.editor = editor;
        this.colorHover = colorHover;
        this.standalone = standalone;
        final editorModel = editor.getModel();
        final model = colorHover.model;
        this.range = new Range(colorHover.range.startLineNumber, colorHover.range.startColumn, colorHover.range.endLineNumber, colorHover.range.endColumn);

        if (standalone) {
            final color = colorHover.model.color;
            this.color = color;
            ColorHoverParticipant._updateColorPresentations(editorModel, model, color, range, colorHover);
            disposables.add(model.onColorFlushed(color -> {
                this.color = color;
            }));
        }
        else {
            disposables.add(model.onColorFlushed(color -> {
                ColorHoverParticipant._updateColorPresentations(editorModel, model, color, range, colorHover).done(_ -> {
                    if (!editor.hasModel() || editor.getModel() != editorModel) {
                        return;
                    }
                    editorUpdatedByColorPicker = true;
                    range = ColorHoverParticipant._updateEditorModel(editor, range, model);
                });
            }));
        }
        disposables.add(model.onDidChangeColor(color -> {
            ColorHoverParticipant._updateColorPresentations(editorModel, model, color, range, colorHover);
        }));
        disposables.add(editor.onDidChangeModelContent(e -> {
            if (editorUpdatedByColorPicker) {
                editorUpdatedByColorPicker = false;
            }
            else {
                hide();
                editor.focus();
            }
        }));
    }

    /**
     * The range of the color in the model (it follows the edits of the
     * picker).
     */
    public function getRange():Range {
        return range;
    }

    /**
     * Monaco's `StandaloneColorPickerParticipant.updateEditorModel`: writes
     * the color of a standalone picker (its Insert button, Enter).
     */
    public function updateEditorModel():Void {
        if (!editor.hasModel()) {
            return;
        }
        final color = this.color;
        if (color != null) {
            final editorModel = editor.getModel();
            final model = colorHover.model;
            ColorHoverParticipant._updateColorPresentations(editorModel, model, color, range, colorHover).done(_ -> {
                editorUpdatedByColorPicker = true;
                range = ColorHoverParticipant._updateEditorModel(editor, range, model);
            });
        }
    }

    public function dispose():Void {
        disposables.dispose();
    }
}

/**
 * The module functions of colorHoverParticipant.ts.
 */
class ColorHoverParticipant {

    /**
     * The color hover of the first color decoration among `lineDecorations`
     * (Monaco's `ColorHoverParticipant._computeAsync`), null when there is
     * none.
     */
    public static function computeColorHover(editor:ICodeEditor, lineDecorations:Array<IModelDecoration>):Promise<ColorHover> {
        if (!editor.hasModel()) {
            return Promise.resolve(null);
        }
        final colorDetector = ColorDetector.get(editor);
        if (colorDetector == null) {
            return Promise.resolve(null);
        }
        for (d in lineDecorations) {
            if (!colorDetector.isColorDecoration(d)) {
                continue;
            }

            final colorData = colorDetector.getColorData(Range.lift(d.range).getStartPosition());
            if (colorData != null) {
                return _createColorHover(editor.getModel(), colorData.colorInfo, colorData.provider);
            }
        }
        return Promise.resolve(null);
    }

    /**
     * Monaco's `_createColorHover`: the picker model of a color, its
     * presentations asked to the provider, the one shown guessed from the
     * text of the color.
     */
    public static function _createColorHover(editorModel:ITextModel, colorInfo:IColorInformation, provider:DocumentColorProvider):Promise<ColorHover> {
        final originalText = editorModel.getValueInRange(colorInfo.range);
        final c = colorInfo.color;
        final rgba = new RGBA(Math.round(c.red * 255), Math.round(c.green * 255), Math.round(c.blue * 255), c.alpha);
        final color = new cityscape.base.common.Color(rgba);

        return ColorUtils.getColorPresentations(editorModel, colorInfo, provider, CancellationTokens.None).then(colorPresentations -> {
            final model = new ColorPickerModel(color, [], 0);
            model.colorPresentations = colorPresentations != null ? colorPresentations : [];
            model.guessColorPresentation(color, originalText);
            return new ColorHover(Range.lift(colorInfo.range), model, provider);
        });
    }

    /**
     * Monaco's `_updateEditorModel`: replaces the color with the presentation
     * (its `textEdit`, else its label over the range) and its additional
     * edits, with an undo stop; returns the new range of the color.
     */
    public static function _updateEditorModel(editor:ICodeEditor, range:Range, model:ColorPickerModel):Range {
        final presentation = model.presentation;
        if (presentation == null) {
            return range;
        }
        final textEdits:Array<IIdentifiedSingleEditOperation> = [];
        final edit:IIdentifiedSingleEditOperation = presentation.textEdit != null
            ? {range: presentation.textEdit.range, text: presentation.textEdit.text}
            : {range: range, text: presentation.label, forceMoveMarkers: false};
        textEdits.push(edit);

        if (presentation.additionalTextEdits != null) {
            for (e in presentation.additionalTextEdits) {
                textEdits.push({range: e.range, text: e.text});
            }
        }
        final replaceRange = Range.lift(edit.range);
        final trackedRange = editor.getModel()._setTrackedRange(null, replaceRange, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter);
        editor.executeEdits('colorpicker', textEdits);
        editor.pushUndoStop();
        final result = trackedRange != null ? editor.getModel()._getTrackedRange(trackedRange) : null;
        if (trackedRange != null) {
            editor.getModel()._setTrackedRange(trackedRange, null, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter);
        }
        return result != null ? result : replaceRange;
    }

    /**
     * Monaco's `_updateColorPresentations`: the presentations of the color
     * asked to the provider again.
     */
    public static function _updateColorPresentations(editorModel:ITextModel, colorPickerModel:ColorPickerModel, color:cityscape.base.common.Color, range:Range, colorHover:ColorHover):Promise<Bool> {
        return ColorUtils.getColorPresentations(editorModel, {
            range: range,
            color: {
                red: color.rgba.r / 255,
                green: color.rgba.g / 255,
                blue: color.rgba.b / 255,
                alpha: color.rgba.a
            }
        }, colorHover.provider, CancellationTokens.None).then(colorPresentations -> {
            colorPickerModel.colorPresentations = colorPresentations != null ? colorPresentations : [];
            return true;
        });
    }

}
