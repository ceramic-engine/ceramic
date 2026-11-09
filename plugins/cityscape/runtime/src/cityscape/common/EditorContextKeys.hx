// Ported from vscode src/vs/editor/common/editorContextKeys.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.platform.contextkey.common.ContextKey;

/**
 * The context keys of the editor. The descriptions are Monaco's English
 * texts (module level values: Cityscape's translation tables belong to a
 * context).
 */
class EditorContextKeys {

    static var _editorSimpleInput:RawContextKey<Bool>;
    public static var editorSimpleInput(get, never):RawContextKey<Bool>;
    static function get_editorSimpleInput():RawContextKey<Bool> {
        if (!_initialized) init();
        return _editorSimpleInput;
    }
    /**
     * A context key that is set when the editor's text has focus (cursor is blinking).
     * Is false when focus is in simple editor widgets (repl input, scm commit input).
     */
    static var _editorTextFocus:RawContextKey<Bool>;
    public static var editorTextFocus(get, never):RawContextKey<Bool>;
    static function get_editorTextFocus():RawContextKey<Bool> {
        if (!_initialized) init();
        return _editorTextFocus;
    }
    /**
     * A context key that is set when the editor's text or an editor's widget has focus.
     */
    static var _focus:RawContextKey<Bool>;
    public static var focus(get, never):RawContextKey<Bool>;
    static function get_focus():RawContextKey<Bool> {
        if (!_initialized) init();
        return _focus;
    }

    /**
     * A context key that is set when any editor input has focus (regular editor, repl input...).
     */
    static var _textInputFocus:RawContextKey<Bool>;
    public static var textInputFocus(get, never):RawContextKey<Bool>;
    static function get_textInputFocus():RawContextKey<Bool> {
        if (!_initialized) init();
        return _textInputFocus;
    }

    static var _readOnly:RawContextKey<Bool>;
    public static var readOnly(get, never):RawContextKey<Bool>;
    static function get_readOnly():RawContextKey<Bool> {
        if (!_initialized) init();
        return _readOnly;
    }
    static var _inDiffEditor:RawContextKey<Bool>;
    public static var inDiffEditor(get, never):RawContextKey<Bool>;
    static function get_inDiffEditor():RawContextKey<Bool> {
        if (!_initialized) init();
        return _inDiffEditor;
    }
    static var _isEmbeddedDiffEditor:RawContextKey<Bool>;
    public static var isEmbeddedDiffEditor(get, never):RawContextKey<Bool>;
    static function get_isEmbeddedDiffEditor():RawContextKey<Bool> {
        if (!_initialized) init();
        return _isEmbeddedDiffEditor;
    }
    static var _inMultiDiffEditor:RawContextKey<Bool>;
    public static var inMultiDiffEditor(get, never):RawContextKey<Bool>;
    static function get_inMultiDiffEditor():RawContextKey<Bool> {
        if (!_initialized) init();
        return _inMultiDiffEditor;
    }
    static var _multiDiffEditorAllCollapsed:RawContextKey<Bool>;
    public static var multiDiffEditorAllCollapsed(get, never):RawContextKey<Bool>;
    static function get_multiDiffEditorAllCollapsed():RawContextKey<Bool> {
        if (!_initialized) init();
        return _multiDiffEditorAllCollapsed;
    }
    static var _hasChanges:RawContextKey<Bool>;
    public static var hasChanges(get, never):RawContextKey<Bool>;
    static function get_hasChanges():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasChanges;
    }
    static var _comparingMovedCode:RawContextKey<Bool>;
    public static var comparingMovedCode(get, never):RawContextKey<Bool>;
    static function get_comparingMovedCode():RawContextKey<Bool> {
        if (!_initialized) init();
        return _comparingMovedCode;
    }
    static var _accessibleDiffViewerVisible:RawContextKey<Bool>;
    public static var accessibleDiffViewerVisible(get, never):RawContextKey<Bool>;
    static function get_accessibleDiffViewerVisible():RawContextKey<Bool> {
        if (!_initialized) init();
        return _accessibleDiffViewerVisible;
    }
    static var _diffEditorRenderSideBySideInlineBreakpointReached:RawContextKey<Bool>;
    public static var diffEditorRenderSideBySideInlineBreakpointReached(get, never):RawContextKey<Bool>;
    static function get_diffEditorRenderSideBySideInlineBreakpointReached():RawContextKey<Bool> {
        if (!_initialized) init();
        return _diffEditorRenderSideBySideInlineBreakpointReached;
    }
    static var _diffEditorInlineMode:RawContextKey<Bool>;
    public static var diffEditorInlineMode(get, never):RawContextKey<Bool>;
    static function get_diffEditorInlineMode():RawContextKey<Bool> {
        if (!_initialized) init();
        return _diffEditorInlineMode;
    }
    static var _diffEditorOriginalWritable:RawContextKey<Bool>;
    public static var diffEditorOriginalWritable(get, never):RawContextKey<Bool>;
    static function get_diffEditorOriginalWritable():RawContextKey<Bool> {
        if (!_initialized) init();
        return _diffEditorOriginalWritable;
    }
    static var _diffEditorModifiedWritable:RawContextKey<Bool>;
    public static var diffEditorModifiedWritable(get, never):RawContextKey<Bool>;
    static function get_diffEditorModifiedWritable():RawContextKey<Bool> {
        if (!_initialized) init();
        return _diffEditorModifiedWritable;
    }
    static var _diffEditorOriginalUri:RawContextKey<String>;
    public static var diffEditorOriginalUri(get, never):RawContextKey<String>;
    static function get_diffEditorOriginalUri():RawContextKey<String> {
        if (!_initialized) init();
        return _diffEditorOriginalUri;
    }
    static var _diffEditorModifiedUri:RawContextKey<String>;
    public static var diffEditorModifiedUri(get, never):RawContextKey<String>;
    static function get_diffEditorModifiedUri():RawContextKey<String> {
        if (!_initialized) init();
        return _diffEditorModifiedUri;
    }
    static var _columnSelection:RawContextKey<Bool>;
    public static var columnSelection(get, never):RawContextKey<Bool>;
    static function get_columnSelection():RawContextKey<Bool> {
        if (!_initialized) init();
        return _columnSelection;
    }
    static var _writable:ContextKeyExpression;
    public static var writable(get, never):ContextKeyExpression;
    static function get_writable():ContextKeyExpression {
        if (!_initialized) init();
        return _writable;
    }
    static var _hasNonEmptySelection:RawContextKey<Bool>;
    public static var hasNonEmptySelection(get, never):RawContextKey<Bool>;
    static function get_hasNonEmptySelection():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasNonEmptySelection;
    }
    static var _hasOnlyEmptySelection:ContextKeyExpression;
    public static var hasOnlyEmptySelection(get, never):ContextKeyExpression;
    static function get_hasOnlyEmptySelection():ContextKeyExpression {
        if (!_initialized) init();
        return _hasOnlyEmptySelection;
    }
    static var _hasMultipleSelections:RawContextKey<Bool>;
    public static var hasMultipleSelections(get, never):RawContextKey<Bool>;
    static function get_hasMultipleSelections():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasMultipleSelections;
    }
    static var _hasSingleSelection:ContextKeyExpression;
    public static var hasSingleSelection(get, never):ContextKeyExpression;
    static function get_hasSingleSelection():ContextKeyExpression {
        if (!_initialized) init();
        return _hasSingleSelection;
    }
    static var _tabMovesFocus:RawContextKey<Bool>;
    public static var tabMovesFocus(get, never):RawContextKey<Bool>;
    static function get_tabMovesFocus():RawContextKey<Bool> {
        if (!_initialized) init();
        return _tabMovesFocus;
    }
    static var _tabDoesNotMoveFocus:ContextKeyExpression;
    public static var tabDoesNotMoveFocus(get, never):ContextKeyExpression;
    static function get_tabDoesNotMoveFocus():ContextKeyExpression {
        if (!_initialized) init();
        return _tabDoesNotMoveFocus;
    }
    static var _isInEmbeddedEditor:RawContextKey<Bool>;
    public static var isInEmbeddedEditor(get, never):RawContextKey<Bool>;
    static function get_isInEmbeddedEditor():RawContextKey<Bool> {
        if (!_initialized) init();
        return _isInEmbeddedEditor;
    }
    static var _canUndo:RawContextKey<Bool>;
    public static var canUndo(get, never):RawContextKey<Bool>;
    static function get_canUndo():RawContextKey<Bool> {
        if (!_initialized) init();
        return _canUndo;
    }
    static var _canRedo:RawContextKey<Bool>;
    public static var canRedo(get, never):RawContextKey<Bool>;
    static function get_canRedo():RawContextKey<Bool> {
        if (!_initialized) init();
        return _canRedo;
    }

    static var _hoverVisible:RawContextKey<Bool>;
    public static var hoverVisible(get, never):RawContextKey<Bool>;
    static function get_hoverVisible():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hoverVisible;
    }
    static var _hoverFocused:RawContextKey<Bool>;
    public static var hoverFocused(get, never):RawContextKey<Bool>;
    static function get_hoverFocused():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hoverFocused;
    }

    static var _stickyScrollFocused:RawContextKey<Bool>;
    public static var stickyScrollFocused(get, never):RawContextKey<Bool>;
    static function get_stickyScrollFocused():RawContextKey<Bool> {
        if (!_initialized) init();
        return _stickyScrollFocused;
    }
    static var _stickyScrollVisible:RawContextKey<Bool>;
    public static var stickyScrollVisible(get, never):RawContextKey<Bool>;
    static function get_stickyScrollVisible():RawContextKey<Bool> {
        if (!_initialized) init();
        return _stickyScrollVisible;
    }

    static var _standaloneColorPickerVisible:RawContextKey<Bool>;
    public static var standaloneColorPickerVisible(get, never):RawContextKey<Bool>;
    static function get_standaloneColorPickerVisible():RawContextKey<Bool> {
        if (!_initialized) init();
        return _standaloneColorPickerVisible;
    }
    static var _standaloneColorPickerFocused:RawContextKey<Bool>;
    public static var standaloneColorPickerFocused(get, never):RawContextKey<Bool>;
    static function get_standaloneColorPickerFocused():RawContextKey<Bool> {
        if (!_initialized) init();
        return _standaloneColorPickerFocused;
    }
    /**
     * A context key that is set when an editor is part of a larger editor, like notebooks or
     * (future) a diff editor
     */
    static var _inCompositeEditor:RawContextKey<Bool>;
    public static var inCompositeEditor(get, never):RawContextKey<Bool>;
    static function get_inCompositeEditor():RawContextKey<Bool> {
        if (!_initialized) init();
        return _inCompositeEditor;
    }
    static var _notInCompositeEditor:ContextKeyExpression;
    public static var notInCompositeEditor(get, never):ContextKeyExpression;
    static function get_notInCompositeEditor():ContextKeyExpression {
        if (!_initialized) init();
        return _notInCompositeEditor;
    }

    // -- mode context keys
    static var _languageId:RawContextKey<String>;
    public static var languageId(get, never):RawContextKey<String>;
    static function get_languageId():RawContextKey<String> {
        if (!_initialized) init();
        return _languageId;
    }
    static var _hasCompletionItemProvider:RawContextKey<Bool>;
    public static var hasCompletionItemProvider(get, never):RawContextKey<Bool>;
    static function get_hasCompletionItemProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasCompletionItemProvider;
    }
    static var _hasCodeActionsProvider:RawContextKey<Bool>;
    public static var hasCodeActionsProvider(get, never):RawContextKey<Bool>;
    static function get_hasCodeActionsProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasCodeActionsProvider;
    }
    static var _hasCodeLensProvider:RawContextKey<Bool>;
    public static var hasCodeLensProvider(get, never):RawContextKey<Bool>;
    static function get_hasCodeLensProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasCodeLensProvider;
    }
    static var _hasDefinitionProvider:RawContextKey<Bool>;
    public static var hasDefinitionProvider(get, never):RawContextKey<Bool>;
    static function get_hasDefinitionProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasDefinitionProvider;
    }
    static var _hasDeclarationProvider:RawContextKey<Bool>;
    public static var hasDeclarationProvider(get, never):RawContextKey<Bool>;
    static function get_hasDeclarationProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasDeclarationProvider;
    }
    static var _hasImplementationProvider:RawContextKey<Bool>;
    public static var hasImplementationProvider(get, never):RawContextKey<Bool>;
    static function get_hasImplementationProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasImplementationProvider;
    }
    static var _hasTypeDefinitionProvider:RawContextKey<Bool>;
    public static var hasTypeDefinitionProvider(get, never):RawContextKey<Bool>;
    static function get_hasTypeDefinitionProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasTypeDefinitionProvider;
    }
    static var _hasHoverProvider:RawContextKey<Bool>;
    public static var hasHoverProvider(get, never):RawContextKey<Bool>;
    static function get_hasHoverProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasHoverProvider;
    }
    static var _hasDocumentHighlightProvider:RawContextKey<Bool>;
    public static var hasDocumentHighlightProvider(get, never):RawContextKey<Bool>;
    static function get_hasDocumentHighlightProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasDocumentHighlightProvider;
    }
    static var _hasDocumentSymbolProvider:RawContextKey<Bool>;
    public static var hasDocumentSymbolProvider(get, never):RawContextKey<Bool>;
    static function get_hasDocumentSymbolProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasDocumentSymbolProvider;
    }
    static var _hasReferenceProvider:RawContextKey<Bool>;
    public static var hasReferenceProvider(get, never):RawContextKey<Bool>;
    static function get_hasReferenceProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasReferenceProvider;
    }
    static var _hasRenameProvider:RawContextKey<Bool>;
    public static var hasRenameProvider(get, never):RawContextKey<Bool>;
    static function get_hasRenameProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasRenameProvider;
    }
    static var _hasSignatureHelpProvider:RawContextKey<Bool>;
    public static var hasSignatureHelpProvider(get, never):RawContextKey<Bool>;
    static function get_hasSignatureHelpProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasSignatureHelpProvider;
    }
    static var _hasInlayHintsProvider:RawContextKey<Bool>;
    public static var hasInlayHintsProvider(get, never):RawContextKey<Bool>;
    static function get_hasInlayHintsProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasInlayHintsProvider;
    }

    // -- mode context keys: formatting
    static var _hasDocumentFormattingProvider:RawContextKey<Bool>;
    public static var hasDocumentFormattingProvider(get, never):RawContextKey<Bool>;
    static function get_hasDocumentFormattingProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasDocumentFormattingProvider;
    }
    static var _hasDocumentSelectionFormattingProvider:RawContextKey<Bool>;
    public static var hasDocumentSelectionFormattingProvider(get, never):RawContextKey<Bool>;
    static function get_hasDocumentSelectionFormattingProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasDocumentSelectionFormattingProvider;
    }
    static var _hasMultipleDocumentFormattingProvider:RawContextKey<Bool>;
    public static var hasMultipleDocumentFormattingProvider(get, never):RawContextKey<Bool>;
    static function get_hasMultipleDocumentFormattingProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasMultipleDocumentFormattingProvider;
    }
    static var _hasMultipleDocumentSelectionFormattingProvider:RawContextKey<Bool>;
    public static var hasMultipleDocumentSelectionFormattingProvider(get, never):RawContextKey<Bool>;
    static function get_hasMultipleDocumentSelectionFormattingProvider():RawContextKey<Bool> {
        if (!_initialized) init();
        return _hasMultipleDocumentSelectionFormattingProvider;
    }


    static var _initialized = false;

    /**
     * Creates the keys on first use (static initialization order between
     * classes is not guaranteed on every target).
     */
    static function init():Void {
        _initialized = true;
        _editorSimpleInput = new RawContextKey<Bool>('editorSimpleInput', false, true);
        _editorTextFocus = new RawContextKey<Bool>('editorTextFocus', false, "Whether the editor text has focus (cursor is blinking)");
        _focus = new RawContextKey<Bool>('editorFocus', false, "Whether the editor or an editor widget has focus (e.g. focus is in the find widget)");
        _textInputFocus = new RawContextKey<Bool>('textInputFocus', false, "Whether an editor or a rich text input has focus (cursor is blinking)");
        _readOnly = new RawContextKey<Bool>('editorReadonly', false, "Whether the editor is read-only");
        _inDiffEditor = new RawContextKey<Bool>('inDiffEditor', false, "Whether the context is a diff editor");
        _isEmbeddedDiffEditor = new RawContextKey<Bool>('isEmbeddedDiffEditor', false, "Whether the context is an embedded diff editor");
        _inMultiDiffEditor = new RawContextKey<Bool>('inMultiDiffEditor', false, "Whether the context is a multi diff editor");
        _multiDiffEditorAllCollapsed = new RawContextKey<Bool>('multiDiffEditorAllCollapsed', null, "Whether all files in multi diff editor are collapsed");
        _hasChanges = new RawContextKey<Bool>('diffEditorHasChanges', false, "Whether the diff editor has changes");
        _comparingMovedCode = new RawContextKey<Bool>('comparingMovedCode', false, "Whether a moved code block is selected for comparison");
        _accessibleDiffViewerVisible = new RawContextKey<Bool>('accessibleDiffViewerVisible', false, "Whether the accessible diff viewer is visible");
        _diffEditorRenderSideBySideInlineBreakpointReached = new RawContextKey<Bool>('diffEditorRenderSideBySideInlineBreakpointReached', false, "Whether the diff editor render side by side inline breakpoint is reached");
        _diffEditorInlineMode = new RawContextKey<Bool>('diffEditorInlineMode', false, "Whether inline mode is active");
        _diffEditorOriginalWritable = new RawContextKey<Bool>('diffEditorOriginalWritable', false, "Whether modified is writable in the diff editor");
        _diffEditorModifiedWritable = new RawContextKey<Bool>('diffEditorModifiedWritable', false, "Whether modified is writable in the diff editor");
        _diffEditorOriginalUri = new RawContextKey<String>('diffEditorOriginalUri', '', "The uri of the original document");
        _diffEditorModifiedUri = new RawContextKey<String>('diffEditorModifiedUri', '', "The uri of the modified document");
        _columnSelection = new RawContextKey<Bool>('editorColumnSelection', false, "Whether `editor.columnSelection` is enabled");
        _writable = _readOnly.toNegated();
        _hasNonEmptySelection = new RawContextKey<Bool>('editorHasSelection', false, "Whether the editor has text selected");
        _hasOnlyEmptySelection = _hasNonEmptySelection.toNegated();
        _hasMultipleSelections = new RawContextKey<Bool>('editorHasMultipleSelections', false, "Whether the editor has multiple selections");
        _hasSingleSelection = _hasMultipleSelections.toNegated();
        _tabMovesFocus = new RawContextKey<Bool>('editorTabMovesFocus', false, "Whether `Tab` will move focus out of the editor");
        _tabDoesNotMoveFocus = _tabMovesFocus.toNegated();
        _isInEmbeddedEditor = new RawContextKey<Bool>('isInEmbeddedEditor', false, true);
        _canUndo = new RawContextKey<Bool>('canUndo', false, true);
        _canRedo = new RawContextKey<Bool>('canRedo', false, true);
        _hoverVisible = new RawContextKey<Bool>('editorHoverVisible', false, "Whether the editor hover is visible");
        _hoverFocused = new RawContextKey<Bool>('editorHoverFocused', false, "Whether the editor hover is focused");
        _stickyScrollFocused = new RawContextKey<Bool>('stickyScrollFocused', false, "Whether the sticky scroll is focused");
        _stickyScrollVisible = new RawContextKey<Bool>('stickyScrollVisible', false, "Whether the sticky scroll is visible");
        _standaloneColorPickerVisible = new RawContextKey<Bool>('standaloneColorPickerVisible', false, "Whether the standalone color picker is visible");
        _standaloneColorPickerFocused = new RawContextKey<Bool>('standaloneColorPickerFocused', false, "Whether the standalone color picker is focused");
        _inCompositeEditor = new RawContextKey<Bool>('inCompositeEditor', null, "Whether the editor is part of a larger editor (e.g. notebooks)");
        _notInCompositeEditor = _inCompositeEditor.toNegated();
        _languageId = new RawContextKey<String>('editorLangId', '', "The language identifier of the editor");
        _hasCompletionItemProvider = new RawContextKey<Bool>('editorHasCompletionItemProvider', false, "Whether the editor has a completion item provider");
        _hasCodeActionsProvider = new RawContextKey<Bool>('editorHasCodeActionsProvider', false, "Whether the editor has a code actions provider");
        _hasCodeLensProvider = new RawContextKey<Bool>('editorHasCodeLensProvider', false, "Whether the editor has a code lens provider");
        _hasDefinitionProvider = new RawContextKey<Bool>('editorHasDefinitionProvider', false, "Whether the editor has a definition provider");
        _hasDeclarationProvider = new RawContextKey<Bool>('editorHasDeclarationProvider', false, "Whether the editor has a declaration provider");
        _hasImplementationProvider = new RawContextKey<Bool>('editorHasImplementationProvider', false, "Whether the editor has an implementation provider");
        _hasTypeDefinitionProvider = new RawContextKey<Bool>('editorHasTypeDefinitionProvider', false, "Whether the editor has a type definition provider");
        _hasHoverProvider = new RawContextKey<Bool>('editorHasHoverProvider', false, "Whether the editor has a hover provider");
        _hasDocumentHighlightProvider = new RawContextKey<Bool>('editorHasDocumentHighlightProvider', false, "Whether the editor has a document highlight provider");
        _hasDocumentSymbolProvider = new RawContextKey<Bool>('editorHasDocumentSymbolProvider', false, "Whether the editor has a document symbol provider");
        _hasReferenceProvider = new RawContextKey<Bool>('editorHasReferenceProvider', false, "Whether the editor has a reference provider");
        _hasRenameProvider = new RawContextKey<Bool>('editorHasRenameProvider', false, "Whether the editor has a rename provider");
        _hasSignatureHelpProvider = new RawContextKey<Bool>('editorHasSignatureHelpProvider', false, "Whether the editor has a signature help provider");
        _hasInlayHintsProvider = new RawContextKey<Bool>('editorHasInlayHintsProvider', false, "Whether the editor has an inline hints provider");
        _hasDocumentFormattingProvider = new RawContextKey<Bool>('editorHasDocumentFormattingProvider', false, "Whether the editor has a document formatting provider");
        _hasDocumentSelectionFormattingProvider = new RawContextKey<Bool>('editorHasDocumentSelectionFormattingProvider', false, "Whether the editor has a document selection formatting provider");
        _hasMultipleDocumentFormattingProvider = new RawContextKey<Bool>('editorHasMultipleDocumentFormattingProvider', false, "Whether the editor has multiple document formatting providers");
        _hasMultipleDocumentSelectionFormattingProvider = new RawContextKey<Bool>('editorHasMultipleDocumentSelectionFormattingProvider', false, "Whether the editor has multiple document selection formatting providers");
    }

}
