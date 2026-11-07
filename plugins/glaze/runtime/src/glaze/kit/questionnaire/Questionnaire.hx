// Ported from gpui-kit 0.8.1: crates/component/src/questionnaire/components.rs and mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.questionnaire;

import glaze.AnyElement;
import glaze.App;
import glaze.ElementId;
import glaze.Empty;
import glaze.Entity;
import glaze.FontWeight;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.OperatingSystem;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.RenderOnce;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.RadioGroup;
import glaze.kit.base.questionnaire.QuestionnaireChoiceControl;
import glaze.kit.base.questionnaire.QuestionnaireChoiceState;
import glaze.kit.base.questionnaire.QuestionnaireItemDefinition;
import glaze.kit.base.questionnaire.QuestionnaireKeyboard;
import glaze.kit.base.questionnaire.QuestionnaireState;
import glaze.kit.base.questionnaire.QuestionnaireValidationError;
import glaze.kit.base.theme.TextStyleToken;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.input.Input;
import glaze.kit.kbd.Kbd;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;

/**
 * Rust `ChoiceRenderer`: renders a custom indicator or shortcut for a choice.
 */
typedef ChoiceRenderer = (QuestionnaireChoiceState, Window, App) -> IntoElement;

/**
 * Where a questionnaire's scale lives between the root and its parts.
 *
 * GPUI has no style cascade, and `with_rem_size` resolves during layout, which
 * a `RenderOnce` part cannot reach. So the root records the scale it was given
 * under its state's id, and every part of that questionnaire reads it back. A
 * part still accepts its own `withSize`, which wins.
 *
 * A root renders before its children, so the entry is in place by the time a
 * part looks for it; a part rendered outside a root falls back to `Medium`.
 *
 * GPUI globals are not observed by views; the port reads and writes this one
 * outside of the tracker, so publishing a size never redraws a view.
 */
class QuestionnaireSizes {

    public final sizes:Map<Int, Size> = new Map();

    public function new() {}

    /**
     * Bounded so an application that builds and drops many questionnaires
     * cannot grow the table without end. Every root rewrites its entry on the
     * next frame, so clearing it costs at most one frame at the default scale.
     */
    static inline final MAX_TRACKED_QUESTIONNAIRES:Int = 128;

    static function global(cx:App, create:Bool):Null<QuestionnaireSizes> {
        tracker.Autorun.unobserve();
        var sizes = cx.tryGlobal(QuestionnaireSizes);
        if (sizes == null && create) {
            sizes = new QuestionnaireSizes();
            cx.setGlobal(sizes);
        }
        tracker.Autorun.reobserve();
        return sizes;
    }

    @:allow(glaze.kit.questionnaire)
    static function publish(state:Entity<QuestionnaireState>, size:Size, cx:App):Void {
        final id = state.entityId();
        final sizes = global(cx, true).sizes;
        var count = 0;
        for (_ in sizes) count++;
        if (count >= MAX_TRACKED_QUESTIONNAIRES && !sizes.exists(id)) {
            sizes.clear();
        }
        sizes.set(id, size);
    }

    @:allow(glaze.kit.questionnaire)
    static function resolve(own:Null<Size>, state:Entity<QuestionnaireState>, cx:App):Size {
        if (own != null) return own;
        final sizes = global(cx, false);
        if (sizes != null) {
            final size = sizes.sizes.get(state.entityId());
            if (size != null) return size;
        }
        return Medium;
    }

}

/**
 * The questionnaire skin's geometry, following the ReUI `base-nova`
 * questionnaire at `Medium`. Every number comes from the semantic spacing and
 * radius tokens; the size picks which of them apply.
 */
@:allow(glaze.kit.questionnaire)
class QuestionnaireMetrics {

    var rootGap:Pixels;
    var itemGap:Pixels;
    var choicesGap:Pixels;
    var choiceGap:Pixels;
    var contentGap:Pixels;
    var choicePaddingX:Pixels;
    var choicePaddingY:Pixels;
    var choiceMinHeight:Pixels;
    var choiceRadius:Pixels;
    var indicatorSize:Pixels;
    var indicatorMarkSize:Pixels;
    var indicatorCheckSize:Pixels;
    var shortcutSize:Pixels;
    var shortcutTextSize:Pixels;
    var shortcutRadius:Pixels;

    function new(size:Size, cx:App) {
        final tokens = Theme.global(cx).semanticTokens();
        final spacing = tokens.spacing;
        final radius = tokens.radius;
        // Rust adds and scales `Pixels` in f32.
        inline function f(value:Float):Pixels return glaze.SpringMath.f32(value);
        switch size {
            case XSmall:
                rootGap = spacing.sm;
                itemGap = spacing.sm;
                choicesGap = spacing.xs;
                choiceGap = f(spacing.xs + spacing.xxs);
                contentGap = spacing.xxs;
                choicePaddingX = spacing.sm;
                choicePaddingY = spacing.xs;
                choiceMinHeight = f(spacing.xl + spacing.xs);
                choiceRadius = radius.md;
                indicatorSize = spacing.md;
                indicatorMarkSize = f(spacing.xs + f(spacing.xxs * 0.5));
                indicatorCheckSize = f(spacing.sm + spacing.xxs);
                shortcutSize = spacing.lg;
                shortcutTextSize = spacing.sm;
                shortcutRadius = radius.sm;
            case Small:
                rootGap = spacing.md;
                itemGap = spacing.md;
                choicesGap = f(spacing.xs + spacing.xxs);
                choiceGap = spacing.sm;
                contentGap = spacing.xxs;
                choicePaddingX = f(spacing.sm + spacing.xxs);
                choicePaddingY = spacing.sm;
                choiceMinHeight = f(spacing.xxl + spacing.xs);
                choiceRadius = radius.lg;
                indicatorSize = f(spacing.md + spacing.xxs);
                indicatorMarkSize = f(spacing.xs + spacing.xxs);
                indicatorCheckSize = spacing.md;
                shortcutSize = f(spacing.lg + spacing.xxs);
                shortcutTextSize = f(spacing.sm + f(spacing.xxs * 0.5));
                shortcutRadius = radius.md;
            case Large:
                rootGap = spacing.xl;
                itemGap = spacing.xl;
                choicesGap = f(spacing.sm + spacing.xxs);
                choiceGap = spacing.md;
                contentGap = spacing.xs;
                choicePaddingX = spacing.lg;
                choicePaddingY = spacing.md;
                choiceMinHeight = f(spacing.xxl + spacing.lg);
                choiceRadius = radius.xl;
                indicatorSize = f(spacing.lg + spacing.xxs);
                indicatorMarkSize = f(spacing.sm + spacing.xxs);
                indicatorCheckSize = spacing.lg;
                shortcutSize = spacing.xl;
                shortcutTextSize = spacing.md;
                shortcutRadius = radius.lg;
            case Size(value):
                rootGap = value;
                itemGap = value;
                choicesGap = f(value * 0.5);
                choiceGap = f(value * 0.625);
                contentGap = f(value * 0.125);
                choicePaddingX = f(value * 0.75);
                choicePaddingY = f(value * 0.625);
                choiceMinHeight = f(value * 2.75);
                choiceRadius = radius.lg;
                indicatorSize = value;
                indicatorMarkSize = f(value * 0.5);
                indicatorCheckSize = f(value * 0.875);
                shortcutSize = f(value * 1.25);
                shortcutTextSize = f(value * 0.625);
                shortcutRadius = radius.md;
            case Medium:
                rootGap = spacing.lg;
                itemGap = spacing.lg;
                choicesGap = spacing.sm;
                choiceGap = f(spacing.sm + spacing.xxs);
                contentGap = spacing.xxs;
                choicePaddingX = spacing.md;
                choicePaddingY = f(spacing.sm + spacing.xxs);
                choiceMinHeight = f(spacing.xxl + spacing.md);
                choiceRadius = radius.lg;
                indicatorSize = spacing.lg;
                indicatorMarkSize = spacing.sm;
                indicatorCheckSize = f(spacing.md + spacing.xxs);
                shortcutSize = f(spacing.lg + spacing.xs);
                shortcutTextSize = f(spacing.sm + spacing.xxs);
                shortcutRadius = radius.md;
        }
    }

}

/**
 * The text styles and helpers shared by the questionnaire parts.
 */
@:allow(glaze.kit.questionnaire)
class QuestionnaireStyles {

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    static function applyTextToken<T:Styled>(element:T, token:TextStyleToken):T {
        new StyleBuilder(element.style()).textSize(token.size).lineHeight(token.lineHeight).fontWeight(token.weight);
        return element;
    }

    /** Answer text matches the Checkbox and Radio family's label at each size. */
    static function textStyle<T:Styled>(element:T, size:Size, cx:App):T {
        final typography = Theme.global(cx).semanticTokens().typography;
        return switch size {
            case XSmall: applyTextToken(element, typography.xs);
            case Small: applyTextToken(element, typography.sm);
            case Large: applyTextToken(element, typography.lg);
            case Size(value):
                new StyleBuilder(element.style()).textSize(px(value));
                element;
            case Medium: applyTextToken(element, typography.md);
        }
    }

    /** Secondary text sits one step below the answer text. */
    static function secondaryTextStyle<T:Styled>(element:T, size:Size, cx:App):T {
        final typography = Theme.global(cx).semanticTokens().typography;
        return switch size {
            case XSmall | Small: applyTextToken(element, typography.xs);
            case Large: applyTextToken(element, typography.md);
            case Size(value):
                new StyleBuilder(element.style()).textSize(px(f32(value * 0.875)));
                element;
            case Medium: applyTextToken(element, typography.sm);
        }
    }

    static function progressTextStyle<T:Styled>(element:T, size:Size, cx:App):T {
        final typography = Theme.global(cx).semanticTokens().typography;
        switch size {
            case Large: applyTextToken(element, typography.sm);
            case Size(value): new StyleBuilder(element.style()).textSize(px(f32(value * 0.75)));
            case _: applyTextToken(element, typography.xs);
        }
        new StyleBuilder(element.style()).fontWeight(FontWeight.MEDIUM);
        return element;
    }

    static function descriptionTextStyle<T:Styled>(element:T, size:Size, cx:App):T {
        return secondaryTextStyle(element, size, cx);
    }

    static function titleTextStyle<T:Styled>(element:T, size:Size, cx:App):T {
        final typography = Theme.global(cx).semanticTokens().typography;
        switch size {
            case XSmall: applyTextToken(element, typography.sm);
            case Small: applyTextToken(element, typography.md);
            case Large: applyTextToken(element, typography.xl);
            case Size(value): new StyleBuilder(element.style()).textSize(px(f32(value * 1.125)));
            case Medium: applyTextToken(element, typography.lg);
        }
        new StyleBuilder(element.style()).fontWeight(FontWeight.MEDIUM);
        return element;
    }

    /**
     * The line box the answer label occupies. An indicator or a shortcut badge
     * centers on that first line, so a two-line answer keeps them beside the
     * label rather than drifting toward the description.
     */
    static function answerLineHeight(size:Size, cx:App):Pixels {
        final typography = Theme.global(cx).semanticTokens().typography;
        return switch size {
            case XSmall: typography.xs.lineHeight;
            case Small: typography.sm.lineHeight;
            case Large: typography.lg.lineHeight;
            case Size(value): f32(value * 1.5);
            case Medium: typography.md.lineHeight;
        }
    }

    /** How far to push an adornment of `height` down so it centers on that line. */
    static function centerOnAnswerLine(height:Pixels, size:Size, cx:App):Pixels {
        final offset = f32(f32(answerLineHeight(size, cx) - height) * 0.5);
        return offset > 0 ? offset : 0;
    }

    static function itemLabel(definition:QuestionnaireItemDefinition):Null<String> {
        return definition.accessibilityLabel();
    }

    static function itemDescription(definition:QuestionnaireItemDefinition):Null<String> {
        return definition.description();
    }

    /**
     * A part addresses its question by name. A name the schema does not define
     * renders nothing, which is silent enough to hide a typo, so a debug build
     * names what went missing. It is a warning rather than an assertion because
     * one view may legitimately render the parts of several questionnaires and
     * hand each a state that defines only some of them.
     */
    static function reportUnknownItem(item:String):Void {
        #if debug
        ceramic.Shortcuts.log.warning('questionnaire has no item named `$item`; the part renders nothing');
        #end
    }

    /** The same for a choice value inside a question that does exist. */
    static function reportUnknownChoice(item:String, value:String):Void {
        #if debug
        ceramic.Shortcuts.log.warning('questionnaire item `$item` has no choice named `$value`; the part renders nothing');
        #end
    }

    static function elementId(state:Entity<QuestionnaireState>, suffix:String):ElementId {
        return ElementId.Name('questionnaire-' + state.entityId() + '-' + suffix);
    }

    /** Base reports why an item failed; the skin owns the sentence a person reads. */
    static function errorText(error:QuestionnaireValidationError):String {
        return switch error {
            case Required: I18n.t('Questionnaire.error.required');
            case Unanswered: I18n.t('Questionnaire.error.optional');
            case Message(message): message;
        }
    }

}

/**
 * The composable questionnaire root. It owns layout and keyboard routing while
 * `QuestionnaireState` remains the single source of behavioral state.
 */
class Questionnaire implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the root exports. */
    public final a11y:A11y = new A11y(Role.Form);

    public function new(state:Entity<QuestionnaireState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):Questionnaire {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Questionnaire {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Questionnaire {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        // The root is the one place a caller names the scale, so it records it
        // for the parts before any of them render.
        final size = sizeValue != null ? sizeValue : Medium;
        QuestionnaireSizes.publish(state, size, cx);
        final metrics = new QuestionnaireMetrics(size, cx);
        final focusHandle = state.read(cx).focusHandle();
        final state = this.state;
        final debugSelector = 'questionnaire-' + state.entityId() + '-root';

        return div()
            .id(QuestionnaireStyles.elementId(state, 'root'))
            .debugSelector(() -> debugSelector)
            .keyContext('Questionnaire')
            .trackFocus(focusHandle)
            .captureKeyDown((event, window, cx) -> QuestionnaireKeyboard.handleKeyDown(state, event, window, cx))
            .flex()
            .flexCol()
            .minW0()
            .gap(metrics.rootGap)
            .wFull()
            .refineStyle(partStyle)
            .children(cast childElements);
    }

}

/**
 * Textual progress, following the ReUI `base-nova` questionnaire skin.
 */
class QuestionnaireProgress implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the part exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.ProgressIndicator);

    public function new(state:Entity<QuestionnaireState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireProgress {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireProgress {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireProgress {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final progress = state.read(cx).progress();
        final current = progress.current();
        final total = progress.total();
        final label = I18n.t('Questionnaire.progress', {current: current, total: total});
        final colors = Theme.global(cx).semanticTokens().colors;
        final hasChildren = childElements.length > 0;

        a11y.label = label;
        a11y.minNumericValue = 0.;
        a11y.maxNumericValue = total;
        a11y.numericValue = current;

        final size = QuestionnaireSizes.resolve(sizeValue, state, cx);
        final element = QuestionnaireStyles.progressTextStyle(div()
            .id(QuestionnaireStyles.elementId(state, 'progress'))
            .textColor(colors.mutedForeground), size, cx)
            .refineStyle(partStyle);
        if (!hasChildren) element.child(label);
        return element.children(cast childElements);
    }

}

/**
 * The question of an item (its accessibility label unless children replace it).
 */
class QuestionnaireTitle implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final item:String;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<QuestionnaireState>, item:String) {
        this.state = state;
        this.item = item;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireTitle {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireTitle {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireTitle {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        return QuestionnaireItemPart.render(state, item, partStyle, sizeValue, childElements, true, cx);
    }

}

/**
 * The description of an item (its definition's description unless children
 * replace it).
 */
class QuestionnaireDescription implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final item:String;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<QuestionnaireState>, item:String) {
        this.state = state;
        this.item = item;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireDescription {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireDescription {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireDescription {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        return QuestionnaireItemPart.render(state, item, partStyle, sizeValue, childElements, false, cx);
    }

}

/**
 * Rust's `questionnaire_item_part!` render, shared by the title (`isTitle`)
 * and the description.
 */
class QuestionnaireItemPart {

    @:allow(glaze.kit.questionnaire)
    static function render(state:Entity<QuestionnaireState>, item:String, partStyle:StyleRefinement, sizeValue:Null<Size>, childElements:Array<AnyElement>,
            isTitle:Bool, cx:App):IntoElement {
        final definition = state.read(cx).itemDefinition(item);
        if (definition == null) {
            QuestionnaireStyles.reportUnknownItem(item);
            return new Empty();
        }
        final fallback = isTitle ? QuestionnaireStyles.itemLabel(definition) : QuestionnaireStyles.itemDescription(definition);
        final hasChildren = childElements.length > 0;
        if (!hasChildren && fallback == null) {
            return new Empty();
        }
        final colors = Theme.global(cx).semanticTokens().colors;
        // The item stacks its parts on one gap. A title with no description of
        // its own closes the gap the description would have filled, so answers
        // never crowd the question.
        final closesItemGap = isTitle && QuestionnaireStyles.itemDescription(definition) == null;
        final size = QuestionnaireSizes.resolve(sizeValue, state, cx);
        final base = div().wFull().textColor(isTitle ? colors.foreground : colors.mutedForeground);
        final element = isTitle ? QuestionnaireStyles.titleTextStyle(base, size, cx) : QuestionnaireStyles.descriptionTextStyle(base, size, cx);
        if (closesItemGap) element.mb(new QuestionnaireMetrics(size, cx).itemGap);
        element.refineStyle(partStyle);
        if (!hasChildren && fallback != null) element.child(fallback);
        return element.children(cast childElements);
    }

}

/**
 * The active question group. Inactive or disabled items do not enter layout,
 * focus traversal, or the accessibility tree.
 */
class QuestionnaireItem implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final item:String;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the part exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Group);

    public function new(state:Entity<QuestionnaireState>, item:String) {
        this.state = state;
        this.item = item;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireItem {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireItem {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireItem {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = this.state.read(cx);
        final active = state.currentItem() == item;
        final itemState = state.itemState(item);
        if (itemState == null) {
            QuestionnaireStyles.reportUnknownItem(item);
            return new Empty();
        }
        if (!active || itemState.isDisabled()) {
            return new Empty();
        }
        final definition = state.itemDefinition(item);
        if (definition == null) {
            return new Empty();
        }
        final focusHandle = state.itemFocusHandle(item);
        a11y.label = definition.accessibilityLabel();
        a11y.description = definition.description();
        final metrics = new QuestionnaireMetrics(QuestionnaireSizes.resolve(sizeValue, this.state, cx), cx);

        final element = div().id(QuestionnaireStyles.elementId(this.state, 'item-' + item));
        if (focusHandle != null) element.trackFocus(focusHandle.tabIndex(-1).tabStop(false));
        return element
            .flex()
            .flexCol()
            .gap(metrics.itemGap)
            .wFull()
            .refineStyle(partStyle)
            .children(cast childElements);
    }

}

/**
 * Container for an item's answer controls.
 */
class QuestionnaireChoices implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final item:String;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties of a multiple-answer group (a single-answer group is a `RadioGroup`, which has its own). */
    public final a11y:A11y = new A11y(Role.Group);

    public function new(state:Entity<QuestionnaireState>, item:String) {
        this.state = state;
        this.item = item;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireChoices {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireChoices {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireChoices {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = this.state.read(cx);
        final active = state.currentItem() == item;
        final itemState = state.itemState(item);
        if (itemState == null) {
            QuestionnaireStyles.reportUnknownItem(item);
            return new Empty();
        }
        if (!active || itemState.isDisabled()) {
            return new Empty();
        }
        final metrics = new QuestionnaireMetrics(QuestionnaireSizes.resolve(sizeValue, this.state, cx), cx);

        if (itemState.isMultiple()) {
            return div()
                .id(QuestionnaireStyles.elementId(this.state, 'choices-' + item))
                .flex()
                .flexCol()
                .gap(metrics.choicesGap)
                .wFull()
                .refineStyle(partStyle)
                .children(cast childElements);
        }
        else {
            return new RadioGroup(QuestionnaireStyles.elementId(this.state, 'choices-' + item))
                .flex()
                .flexCol()
                .gap(metrics.choicesGap)
                .wFull()
                .refineStyle(partStyle)
                .children(cast childElements);
        }
    }

}

/**
 * A selectable choice card, following the ReUI `base-nova` questionnaire skin.
 */
class QuestionnaireChoice implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final item:String;

    final value:String;

    final partStyle:StyleRefinement = new StyleRefinement();

    var indicatorStyleValue:StyleRefinement = new StyleRefinement();

    var contentStyleValue:StyleRefinement = new StyleRefinement();

    var shortcutStyleValue:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    var indicatorRenderer:Null<ChoiceRenderer> = null;

    var shortcutRenderer:Null<ChoiceRenderer> = null;

    public function new(state:Entity<QuestionnaireState>, item:String, value:String) {
        this.state = state;
        this.item = item;
        this.value = value;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireChoice {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireChoice {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireChoice {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function indicatorStyle(style:StyleRefinement):QuestionnaireChoice {
        indicatorStyleValue = style;
        return this;
    }

    public function contentStyle(style:StyleRefinement):QuestionnaireChoice {
        contentStyleValue = style;
        return this;
    }

    public function shortcutStyle(style:StyleRefinement):QuestionnaireChoice {
        shortcutStyleValue = style;
        return this;
    }

    public function renderIndicator(renderer:ChoiceRenderer):QuestionnaireChoice {
        indicatorRenderer = renderer;
        return this;
    }

    public function renderShortcut(renderer:ChoiceRenderer):QuestionnaireChoice {
        shortcutRenderer = renderer;
        return this;
    }

    static inline function any(element:IntoElement):AnyElement {
        return element;
    }

    static function styleChoiceCard<T:Styled & ParentElement>(base:T, hover:((StyleBuilder) -> StyleBuilder)->Void, indicator:AnyElement, content:AnyElement,
            shortcut:AnyElement, metrics:QuestionnaireMetrics, selected:Bool, disabled:Bool, invalid:Bool, focused:Bool, instanceStyle:StyleRefinement,
            window:Window, cx:App):T {
        final theme = Theme.global(cx);
        final tokens = theme.semanticTokens();
        new StyleBuilder(base.style())
            .flex()
            .itemsStart()
            .gap(metrics.choiceGap)
            .wFull()
            .minH(metrics.choiceMinHeight)
            .px(metrics.choicePaddingX)
            .py(metrics.choicePaddingY)
            .border1()
            .borderColor(if (invalid) {
                tokens.colors.destructive;
            }
            else if (selected) {
                tokens.colors.primary.opacity(0.4);
            }
            else {
                tokens.colors.input;
            })
            .bg(if (selected) {
                tokens.colors.muted;
            }
            else if (theme.isDark()) {
                tokens.colors.input.opacity(0.2);
            }
            else {
                tokens.colors.background.opacity(0.);
            })
            .rounded(metrics.choiceRadius);
        if (!disabled) {
            hover(style -> style.bg(tokens.colors.muted.opacity(0.5)));
        }
        if (focused) base.focusRingStyle(window, cx);
        if (disabled) new StyleBuilder(base.style()).opacity(0.5);
        base.refineStyle(instanceStyle);
        base.extend([indicator, content, shortcut]);
        return base;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = this.state.read(cx);
        final active = state.currentItem() == item;
        final choiceState = state.choiceState(item, value);
        if (choiceState == null) {
            if (state.itemState(item) == null) {
                QuestionnaireStyles.reportUnknownItem(item);
            }
            else {
                QuestionnaireStyles.reportUnknownChoice(item, value);
            }
            return new Empty();
        }
        if (!active) {
            return new Empty();
        }
        final itemState = state.itemState(item);
        if (itemState == null) {
            QuestionnaireStyles.reportUnknownItem(item);
            return new Empty();
        }
        final definition = state.choiceDefinition(item, value);
        if (definition == null) {
            return new Empty();
        }
        final multiple = itemState.isMultiple();
        final label = definition.accessibilityLabel();
        final description = definition.description();
        final selected = choiceState.isSelected();
        final disabled = choiceState.isDisabled();
        final invalid = choiceState.isInvalid();
        final shortcut = choiceState.shortcut();
        final focusHandle = state.choiceFocusHandle(item, value);
        final theme = Theme.global(cx);
        final colors = theme.semanticTokens().colors;
        final radius = theme.semanticTokens().radius;
        final indicatorBackground = theme.inputBackground();
        final monoFont = theme.semanticTokens().typography.mono;
        final size = QuestionnaireSizes.resolve(sizeValue, this.state, cx);
        final metrics = new QuestionnaireMetrics(size, cx);
        final indicatorOffset = QuestionnaireStyles.centerOnAnswerLine(metrics.indicatorSize, size, cx);
        final shortcutOffset = QuestionnaireStyles.centerOnAnswerLine(metrics.shortcutSize, size, cx);
        final focused = focusHandle != null && focusHandle.isFocused(window);
        final hasChildren = childElements.length > 0;
        final checkPath = Icon.resolveIconPath(IconName.Check.path(), cx);

        final defaultIndicator = () -> {
            final element = div()
                .relative()
                .flex()
                .itemsCenter()
                .justifyCenter()
                .flexShrink0()
                .size(metrics.indicatorSize)
                .border1()
                .borderColor(selected ? colors.primary : colors.input)
                .bg(selected ? colors.primary : indicatorBackground);
            if (multiple) element.rounded(radius.sm);
            if (!multiple) element.rounded(radius.full);
            element.refineStyle(indicatorStyleValue);
            if (selected && multiple) {
                element.child(svg()
                    .size(metrics.indicatorCheckSize)
                    .path(checkPath)
                    .textColor(colors.primaryForeground));
            }
            if (selected && !multiple) {
                element.child(div()
                    .size(metrics.indicatorMarkSize)
                    .rounded(radius.full)
                    .bg(colors.primaryForeground));
            }
            return any(element);
        };

        // The slot, not the element, owns the vertical alignment, so a custom
        // indicator lands on the label's line without having to know the metrics.
        final indicator = any(div()
            .flexShrink0()
            .mt(indicatorOffset)
            .child(indicatorRenderer != null ? any(indicatorRenderer(choiceState, window, cx)) : defaultIndicator()));

        final content = div()
            .flex()
            .flex1()
            .flexCol()
            .gap(metrics.contentGap)
            .refineStyle(contentStyleValue);
        if (!hasChildren) {
            content.child(QuestionnaireStyles.textStyle(div().textColor(colors.foreground).child(label), size, cx));
            if (description != null) {
                content.child(QuestionnaireStyles.secondaryTextStyle(div().textColor(colors.mutedForeground).child(description), size, cx));
            }
        }
        content.children(cast childElements);

        final os = OperatingSystem.current;
        final defaultShortcut = () -> {
            if (shortcut == null) {
                return any(new Empty());
            }
            final keystroke = try {
                Keystroke.parseWithOs(shortcut.toLowerCase(), os);
            }
            catch (_:Dynamic) {
                null;
            }
            if (keystroke == null) {
                return any(new Empty());
            }
            return any(new Kbd(keystroke)
                .outline()
                .flex()
                .itemsCenter()
                .justifyCenter()
                .size(metrics.shortcutSize)
                .p0()
                .bg(colors.background)
                .borderColor(colors.input)
                .textColor(colors.mutedForeground)
                .fontFamily(monoFont)
                .textSize(metrics.shortcutTextSize)
                .fontWeight(FontWeight.MEDIUM)
                .rounded(metrics.shortcutRadius)
                .refineStyle(shortcutStyleValue));
        };
        final shortcutElement = any(div()
            .flexShrink0()
            .mt(shortcutOffset)
            .child(shortcutRenderer != null ? any(shortcutRenderer(choiceState, window, cx)) : defaultShortcut()));

        final id = QuestionnaireStyles.elementId(this.state, 'choice-' + item + '-' + value);
        final instanceStyle = partStyle;

        final control = QuestionnaireChoiceControlTools.create(this.state, item, value, id, cx);
        if (control == null) {
            return new Empty();
        }
        return switch control {
            case Checkbox(base):
                styleChoiceCard(base, f -> base.hover(f), indicator, any(content), shortcutElement, metrics, selected, disabled, invalid, focused, instanceStyle, window,
                    cx);
            case Radio(base):
                styleChoiceCard(base, f -> base.hover(f), indicator, any(content), shortcutElement, metrics, selected, disabled, invalid, focused, instanceStyle, window,
                    cx);
        }
    }

}

/**
 * Secondary text for custom choice compositions.
 */
class QuestionnaireChoiceDescription implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireChoiceDescription {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireChoiceDescription {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireChoiceDescription {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final colors = Theme.global(cx).semanticTokens().colors;
        return QuestionnaireStyles.secondaryTextStyle(div().textColor(colors.mutedForeground), sizeValue != null ? sizeValue : Medium, cx)
            .refineStyle(partStyle)
            .children(cast childElements);
    }

}

/**
 * The optional freeform answer input for an item.
 */
class QuestionnaireInput implements RenderOnce implements Styled implements Sizable {

    final state:Entity<QuestionnaireState>;

    final item:String;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    public function new(state:Entity<QuestionnaireState>, item:String) {
        this.state = state;
        this.item = item;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireInput {
        sizeValue = size;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = this.state.read(cx);
        final active = state.currentItem() == item;
        final itemState = state.itemState(item);
        if (itemState == null) {
            QuestionnaireStyles.reportUnknownItem(item);
            return new Empty();
        }
        final definition = state.itemDefinition(item);
        if (definition == null) {
            return new Empty();
        }
        final inputDefinition = definition.input();
        if (inputDefinition == null) {
            return new Empty();
        }
        if (!active) {
            return new Empty();
        }

        final size = QuestionnaireSizes.resolve(sizeValue, this.state, cx);
        final metrics = new QuestionnaireMetrics(size, cx);

        final input = new Input(inputDefinition.state())
            .ariaLabel(inputDefinition.accessibilityLabel())
            .disabled(itemState.isDisabled() || inputDefinition.isDisabled())
            .withSize(size)
            // The freeform answer is one of the answers, so its text starts on
            // the same edge a choice's indicator does: the card padding.
            .pl(metrics.choicePaddingX)
            .rounded(metrics.choiceRadius);
        if (itemState.isInvalid()) {
            input.borderColor(Theme.global(cx).semanticTokens().colors.destructive);
        }
        return input.refineStyle(partStyle);
    }

}

/**
 * Validation error for an item. It only enters the tree while invalid.
 */
class QuestionnaireError implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final item:String;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the part exports (Rust `questionnaire_error_root`). */
    public final a11y:A11y = new A11y(Role.Alert);

    public function new(state:Entity<QuestionnaireState>, item:String) {
        this.state = state;
        this.item = item;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireError {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireError {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireError {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = this.state.read(cx);
        final itemState = state.itemState(item);
        if (itemState == null) {
            QuestionnaireStyles.reportUnknownItem(item);
            return new Empty();
        }
        final error = state.error(item);
        if (!itemState.isInvalid() || error == null) {
            return new Empty();
        }
        final hasChildren = childElements.length > 0;
        final tokens = Theme.global(cx).semanticTokens();
        final size = QuestionnaireSizes.resolve(sizeValue, this.state, cx);

        final element = QuestionnaireStyles.secondaryTextStyle(div()
            .id(QuestionnaireStyles.elementId(this.state, 'error-' + item))
            .mt(tokens.spacing.sm)
            .textColor(tokens.colors.destructive), size, cx)
            .refineStyle(partStyle);
        if (!hasChildren) element.child(QuestionnaireStyles.errorText(error));
        return element.children(cast childElements);
    }

}

/**
 * Layout part for questionnaire navigation actions.
 */
class QuestionnaireActions implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<QuestionnaireState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireActions {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireActions {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireActions {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final metrics = new QuestionnaireMetrics(QuestionnaireSizes.resolve(sizeValue, state, cx), cx);
        final debugSelector = 'questionnaire-' + state.entityId() + '-actions';
        return div()
            .id(QuestionnaireStyles.elementId(state, 'actions'))
            .debugSelector(() -> debugSelector)
            .flex()
            .minW0()
            .itemsCenter()
            .justifyStart()
            .gap(metrics.choicesGap)
            .wFull()
            .refineStyle(partStyle)
            .children(cast childElements);
    }

}

/**
 * The navigation actions (Rust `QuestionnaireAction`).
 */
enum abstract QuestionnaireAction(Int) {
    var Previous = 0;
    var Skip = 1;
    var Next = 2;
    var Submit = 3;

    /** Rust `stringify!($action)`. */
    public function name():String {
        return switch (cast this : QuestionnaireAction) {
            case Previous: 'Previous';
            case Skip: 'Skip';
            case Next: 'Next';
            case Submit: 'Submit';
        }
    }
}

/**
 * Rust's `questionnaire_action_part!` render, shared by the four actions.
 */
class QuestionnaireActionPart {

    @:allow(glaze.kit.questionnaire)
    static function render(state:Entity<QuestionnaireState>, action:QuestionnaireAction, translation:String, outline:Bool, primary:Bool,
            partStyle:StyleRefinement, sizeValue:Null<Size>, childElements:Array<AnyElement>, cx:App):IntoElement {
        final navigation = state.read(cx).navigationState();
        final visible = switch action {
            case Previous: navigation.isPreviousVisible();
            case Skip: navigation.isSkipVisible();
            case Next: navigation.isNextVisible();
            case Submit: navigation.isSubmitVisible();
        }
        if (!visible) {
            return new Empty();
        }

        final anchorsTrailingActions = switch action {
            case Skip: true;
            case Next | Submit: !navigation.isSkipVisible();
            case Previous: false;
        }
        final hasChildren = childElements.length > 0;
        // Rust adds the debug selector `questionnaire-<id>-<action>` (test builds only).
        final button = new glaze.kit.button.Button(QuestionnaireStyles.elementId(state, action.name()))
            .withSize(QuestionnaireSizes.resolve(sizeValue, state, cx));
        if (outline) button.outline();
        if (primary) button.primary();
        if (anchorsTrailingActions) button.mlAuto();
        button.onClick((_, window, cx) -> {
            state.update(cx, (state, cx) -> switch action {
                case Previous: state.goPrevious(window, cx);
                case Skip: state.skipCurrent(window, cx);
                case Next: state.goNext(window, cx);
                case Submit: state.submit(window, cx);
            });
        });
        button.refineStyle(partStyle);
        if (!hasChildren) button.label(I18n.t(translation));
        return button.children(cast childElements);
    }

}

class QuestionnairePrevious implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<QuestionnaireState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnairePrevious {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnairePrevious {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnairePrevious {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        return QuestionnaireActionPart.render(state, Previous, 'Questionnaire.previous', true, false, partStyle, sizeValue, childElements, cx);
    }

}

class QuestionnaireSkip implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<QuestionnaireState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireSkip {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireSkip {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireSkip {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        return QuestionnaireActionPart.render(state, Skip, 'Questionnaire.skip', true, false, partStyle, sizeValue, childElements, cx);
    }

}

class QuestionnaireNext implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<QuestionnaireState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireNext {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireNext {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireNext {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        return QuestionnaireActionPart.render(state, Next, 'Questionnaire.next', false, true, partStyle, sizeValue, childElements, cx);
    }

}

class QuestionnaireSubmit implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<QuestionnaireState>;

    final partStyle:StyleRefinement = new StyleRefinement();

    var sizeValue:Null<Size> = null;

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<QuestionnaireState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function withSize(size:IntoSize):QuestionnaireSubmit {
        sizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):QuestionnaireSubmit {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):QuestionnaireSubmit {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        return QuestionnaireActionPart.render(state, Submit, 'Questionnaire.submit', false, true, partStyle, sizeValue, childElements, cx);
    }

}
