package tests;

import cityscape.Cityscape;
import cityscape.base.common.CharCode;
import cityscape.base.common.Event;
import cityscape.base.common.HtmlContent;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Objects;
import cityscape.base.common.Platform;
import cityscape.base.common.Scrollable;
import cityscape.base.common.Strings;
import cityscape.base.common.Themables;
import cityscape.base.common.Uri;
import cityscape.common.CursorCommon;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon;
import cityscape.common.EditorTheme;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.ModelLineProjectionData;
import cityscape.common.TextModelBracketPairs;
import cityscape.common.TextModelEvents;
import cityscape.common.TextModelGuides;
import cityscape.common.TokenizationTextModelPart;
import cityscape.common.ViewEventHandler;
import cityscape.common.ViewEvents;
import cityscape.common.ViewModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.FontInfo;
import cityscape.common.core.Dimension;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.TextChange;
import cityscape.common.core.TextModelDefaults;
import cityscape.common.core.WordHelper;
import cityscape.common.languages.Language;
import cityscape.common.services.ModelService;
import cityscape.common.tokens.LineTokens;
import cityscape.platform.accessibility.common.Accessibility;
import cityscape.platform.commands.common.Commands;
import cityscape.platform.undoRedo.common.UndoRedo;
import cityscape.view.config.EditorConfiguration;
import cityscape.view.config.MigrateOptions;
import testing.TestCase;

/**
 * Compiles every module of the frozen interfaces (the imports above) and
 * checks a few values against the vscode sources.
 */
class InterfacesTest extends TestCase {

    function testEnumValues() {
        // model.ts
        assertEquals(2, (EndOfLinePreference.CRLF : Int));
        assertEquals(2, (DefaultEndOfLine.CRLF : Int));
        assertEquals(1, (EndOfLineSequence.CRLF : Int));
        assertEquals(3, (TrackedRangeStickiness.GrowsOnlyWhenTypingAfter : Int));
        assertEquals(7, (OverviewRulerLane.Full : Int));
        assertEquals(4, (PositionAffinity.RightOfInjectedText : Int));
        // charCode.ts
        assertEquals(65279, (CharCode.UTF8_BOM : Int));
        assertEquals(0xFF0C, (CharCode.U_FULLWIDTH_COMMA : Int));
        assertEquals(126, (CharCode.Tilde : Int));
        // editorCommon.ts
        assertEquals(1, (ScrollType.Immediate : Int));
        assertEquals('compositionType', (Handler.CompositionType : String));
        // selection.ts
        assertEquals(1, (SelectionDirection.RTL : Int));
    }

    function testCommandImplementation() {
        // A command implements the frozen ICommand interface
        final command:ICommand = new NoopCommand();
        assertEquals(false, command.insertsAutoWhitespace);
    }

    function testEditOperation() {
        final op = EditOperation.insert(new Position(2, 3), 'x');
        assertTrue(Range.equalsRangeStatic(op.range, new Range(2, 3, 2, 3)));
        assertEquals('x', op.text);
        assertEquals(true, op.forceMoveMarkers);
        final del = EditOperation.delete(new Range(1, 1, 1, 4));
        assertEquals(null, del.text);
    }

    function testUndoRedoGroupNone() {
        assertEquals(0, UndoRedoGroup.None.id);
        assertEquals(0, UndoRedoGroup.None.nextOrder());
    }

}

private class NoopCommand implements ICommand {

    public final insertsAutoWhitespace:Bool = false;

    public function new() {}

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {}

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return new Selection(1, 1, 1, 1);
    }

}
