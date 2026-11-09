// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/colorizedBracketPairsDecorationProvider.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.Model;
import cityscape.common.TextModelBracketPairs.BracketInfo;
import cityscape.common.TextModelEvents.IModelOptionsChangedEvent;
import cityscape.common.core.Range;
import cityscape.common.model.DecorationProvider;

/**
 * The decorations that colorize the bracket pairs (inline class names
 * `bracket-highlighting-N` and `unexpected-closing-bracket`).
 *
 * The colors of these class names (Monaco's theming participant,
 * `editorBracketHighlight.foreground1..6` and
 * `editorBracketHighlight.unexpectedBracket.foreground`) are resolved by
 * the view (`DecorationStyleResolver`).
 */
class ColorizedBracketPairsDecorationProvider extends Disposable implements DecorationProvider {

    var colorizationOptions:BracketPairColorizationOptions;
    final colorProvider = new ColorProvider();

    final onDidChangeEmitter = new VoidEmitter();
    public var onDidChange(default, null):VoidEvent;

    final textModel:ITextModel;

    public function new(textModel:ITextModel) {
        super();
        this.textModel = textModel;
        onDidChange = onDidChangeEmitter.event;

        colorizationOptions = textModel.getOptions().bracketPairColorizationOptions;

        _register(textModel.bracketPairs.onDidChange(() -> {
            onDidChangeEmitter.fire();
        }));
    }

    //#region TextModel events

    public function handleDidChangeOptions(e:IModelOptionsChangedEvent):Void {
        colorizationOptions = textModel.getOptions().bracketPairColorizationOptions;
    }

    //#endregion

    public function getDecorationsInRange(range:Range, ?ownerId:Int, ?filterOutValidation:Bool, ?onlyMinimapDecorations:Bool):Array<IModelDecoration> {
        if (onlyMinimapDecorations == true) {
            // Bracket pair colorization decorations are not rendered in the minimap
            return [];
        }
        if (ownerId == null) {
            return [];
        }
        if (!colorizationOptions.enabled) {
            return [];
        }

        final result = textModel.bracketPairs.getBracketsInRange(range, true).map(bracket -> {
            final decoration:IModelDecoration = {
                id: 'bracket' + bracket.range.toString() + '-' + bracket.nestingLevel,
                options: {
                    description: 'BracketPairColorization',
                    inlineClassName: colorProvider.getInlineClassName(
                        bracket,
                        colorizationOptions.independentColorPoolPerBracketType
                    ),
                },
                ownerId: 0,
                range: bracket.range,
            };
            return decoration;
        }).toArray();

        return result;
    }

    public function getAllDecorations(?ownerId:Int, ?filterOutValidation:Bool, ?onlyMinimapDecorations:Bool):Array<IModelDecoration> {
        if (ownerId == null) {
            return [];
        }
        if (!colorizationOptions.enabled) {
            return [];
        }
        return getDecorationsInRange(
            new Range(1, 1, textModel.getLineCount(), 1),
            ownerId,
            filterOutValidation
        );
    }

}

class ColorProvider {

    public final unexpectedClosingBracketClassName = 'unexpected-closing-bracket';

    public function new() {}

    public function getInlineClassName(bracket:BracketInfo, independentColorPoolPerBracketType:Bool):String {
        if (bracket.isInvalid) {
            return unexpectedClosingBracketClassName;
        }
        return getInlineClassNameOfLevel(independentColorPoolPerBracketType ? bracket.nestingLevelOfEqualBracketType : bracket.nestingLevel);
    }

    public function getInlineClassNameOfLevel(level:Int):String {
        // To support a dynamic amount of colors up to 6 colors,
        // we use a number that is a lcm of all numbers from 1 to 6.
        return 'bracket-highlighting-' + (level % 30);
    }

}
