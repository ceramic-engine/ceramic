// Ported from gpui-kit 0.8.1: crates/story/src/stories/diff_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.Action;
import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Subscription;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.diff.Diff;
import glaze.kit.diff.DiffAnnotation;
import glaze.kit.diff.DiffChangeIndicator;
import glaze.kit.diff.DiffDecoration;
import glaze.kit.diff.DiffFile;
import glaze.kit.diff.DiffGutterMarker;
import glaze.kit.diff.DiffHoverHighlight;
import glaze.kit.diff.DiffHunkSeparator;
import glaze.kit.diff.DiffInlineUnit;
import glaze.kit.diff.DiffLinePosition;
import glaze.kit.diff.DiffLineRange;
import glaze.kit.diff.DiffMode;
import glaze.kit.diff.DiffSide;
import glaze.kit.diff.DiffState;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;

enum DiffStoryActionKind {
    Example(index:Int);
    Context(lines:Null<Int>);
    Expand;
    Collapse;
    Inline(index:Int);
    Separator(index:Int);
    Indicator(index:Int);
    Background;
    Hover;
    Wrap;
}

/** Rust `enum DiffStoryAction` (an action). */
@:action(namespace = diff_story, noJson)
class DiffStoryAction implements Action {
    public final value:DiffStoryActionKind;
}

/** An application-owned review comment anchored to the end of its lines. */
private class Comment {

    public final id:ElementId;

    public final range:DiffLineRange;

    public final body:String;

    public var resolved:Bool;

    public function new(id:ElementId, range:DiffLineRange, body:String, resolved:Bool) {
        this.id = id;
        this.range = range;
        this.body = body;
        this.resolved = resolved;
    }

}

class DiffStory extends Model implements Story {

    public static final EXAMPLES:Array<String> = [
        'Pull request',
        'Added file',
        'Deleted file',
        'Unicode',
        'Long lines',
        'Large file',
        'Renamed file',
        'Missing final newline',
        'File mode',
        'Merge conflict',
        'Source file',
    ];

    static final INLINE:Array<{label:String, unit:Null<DiffInlineUnit>}> = [
        {label: 'Words', unit: DiffInlineUnit.Word},
        {label: 'Characters', unit: DiffInlineUnit.Character},
        {label: 'Whole lines', unit: null},
    ];

    static final SEPARATORS:Array<{label:String, separator:DiffHunkSeparator}> = [
        {label: 'Hunk header', separator: DiffHunkSeparator.Metadata},
        {label: 'Hidden line count', separator: DiffHunkSeparator.LineInfo},
        {label: 'Divider', separator: DiffHunkSeparator.Simple},
    ];

    static final INDICATORS:Array<{label:String, indicator:DiffChangeIndicator}> = [
        {label: 'Signs', indicator: DiffChangeIndicator.Signs},
        {label: 'Bars', indicator: DiffChangeIndicator.Bars},
        {label: 'None', indicator: DiffChangeIndicator.None},
    ];

    /** The range dash of "lines 3-5" in the original (U+2013). */
    static final RANGE_DASH:String = String.fromCharCode(0x2013);

    var state:Entity<DiffState>;
    var example:Int;
    final comments:Array<Comment>;
    var inlineIx:Int;
    var separator:Int;
    var indicator:Int;
    var background:Bool;
    var hover:Bool;
    var wrap:Bool;
    var subscription:Subscription;

    public static function title():String {
        return 'Diff';
    }

    public static function description():String {
        return 'Readonly unified and Git patches, merge conflicts and source files, with review comments.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(_window:Window, cx:App):Entity<DiffStory> {
        return cx.newEntity((cx:Context<DiffStory>) -> new DiffStory(cx));
    }

    function new(cx:Context<DiffStory>) {
        super();
        state = cx.newEntity((cx:Context<DiffState>) -> new DiffState(exampleFiles(0), cx));
        subscription = cx.observe(state, (_, _, cx) -> cx.notify());
        example = 0;
        comments = [
            new Comment(ElementId.Name('retry-delay-review'), new DiffLineRange('src/retry.rs', DiffSide.Modified, 21, 21),
                'Should callers be able to configure the 6.4-second delay cap?', false)
        ];
        inlineIx = 0;
        separator = 0;
        indicator = 0;
        background = true;
        hover = false;
        wrap = false;
    }

    /** Rebuilds the state when an option prepared with it changes. */
    function rebuildState(cx:Context<DiffStory>):Void {
        final mode = state.read(cx.app).mode();
        final inlineUnit = INLINE[this.inlineIx].unit;
        final files = exampleFiles(example);
        state = cx.newEntity((cx:Context<DiffState>) -> new DiffState(files, cx)
            .withMode(mode)
            .withInlineUnit(inlineUnit));
        subscription = cx.observe(state, (_, _, cx) -> cx.notify());
    }

    function onDiffAction(action:DiffStoryAction, _:Window, cx:Context<DiffStory>):Void {
        switch action.value {
            case Example(example):
                this.example = example;
                final files = exampleFiles(example);
                state.update(cx, (state, cx) -> state.setFiles(files, cx));
            case Context(lines):
                state.update(cx, (state, cx) -> state.setContextLines(lines, cx));
            case Expand:
                state.update(cx, (state, cx) -> state.expandUnchanged(cx));
            case Collapse:
                state.update(cx, (state, cx) -> state.collapseUnchanged(cx));
            case Inline(ix):
                this.inlineIx = ix;
                rebuildState(cx);
            case Separator(separator):
                this.separator = separator;
            case Indicator(indicator):
                this.indicator = indicator;
            case Background:
                background = !background;
            case Hover:
                hover = !hover;
            case Wrap:
                wrap = !wrap;
        }
        cx.notify();
    }

    function addComment(range:DiffLineRange, cx:Context<DiffStory>):Void {
        final start = range.start() < range.end() ? range.start() : range.end();
        final end = range.start() > range.end() ? range.start() : range.end();
        final lines = start == end ? 'line $end' : 'lines $start$RANGE_DASH$end';
        comments.push(new Comment(ElementId.Name('comment-${comments.length}'), range, 'New comment on $lines.', false));
        cx.notify();
    }

    function renderToolbar(cx:Context<DiffStory>):IntoElement {
        final app = cx.app;
        final example = this.example;
        final mode = state.read(app).mode();
        final context = state.read(app).contextLines();
        final inlineIx = this.inlineIx;
        final separator = this.separator;
        final indicator = this.indicator;
        final background = this.background;
        final hover = this.hover;
        final wrap = this.wrap;
        final hasChanges = Lambda.exists(state.read(app).files(), file -> file.hasChanges());
        return hFlex()
            .wFull()
            .gap2()
            .child(storyToolbarGroup()
                .wAuto()
                .child(Button.component('diff-unified')
                    .label('Unified')
                    .selected(mode == DiffMode.Unified)
                    .onClick(cx.listener((this_:DiffStory, _, _, cx) -> {
                        this_.state.update(cx, (state, cx) -> state.setMode(DiffMode.Unified, cx));
                    })))
                .child(Button.component('diff-split')
                    .label('Split')
                    .selected(mode == DiffMode.Split)
                    .onClick(cx.listener((this_:DiffStory, _, _, cx) -> {
                        this_.state.update(cx, (state, cx) -> state.setMode(DiffMode.Split, cx));
                    }))))
            .child(storyToolbarGroup()
                .wAuto()
                .child(Button.component('diff-previous')
                    .icon(IconName.ArrowUp)
                    .accessibilityLabel('Previous change')
                    .tooltip('Previous change')
                    .disabled(!hasChanges)
                    .onClick(cx.listener((this_:DiffStory, _, _, cx) -> {
                        this_.state.update(cx, (state, cx) -> state.previousChange(cx));
                    })))
                .child(Button.component('diff-next')
                    .icon(IconName.ArrowDown)
                    .accessibilityLabel('Next change')
                    .tooltip('Next change')
                    .disabled(!hasChanges)
                    .onClick(cx.listener((this_:DiffStory, _, _, cx) -> {
                        this_.state.update(cx, (state, cx) -> state.nextChange(cx));
                    }))))
            .child(div().flex1())
            .child(storyToolbarGroup().wAuto().dropdownChild(Button.component('diff-options').label('Options'), (menu, window, cx) -> {
                menu.submenu('Example', window, cx, (menu, _, _) -> {
                    for (index in 0...EXAMPLES.length) {
                        menu = menu.menuWithCheck(EXAMPLES[index], example == index, new DiffStoryAction(Example(index)));
                    }
                    return menu;
                })
                    .submenu('Context', window, cx, (menu, _, _) -> menu
                        .menuWithCheck('Three context lines', context == 3, new DiffStoryAction(Context(3)))
                        .menuWithCheck('All supplied context', context == null, new DiffStoryAction(Context(null)))
                        .separator()
                        .menu('Expand all', new DiffStoryAction(Expand))
                        .menu('Collapse all', new DiffStoryAction(Collapse)))
                    .submenu('Inline changes', window, cx, (menu, _, _) -> {
                        for (ix in 0...INLINE.length) {
                            menu = menu.menuWithCheck(INLINE[ix].label, inlineIx == ix, new DiffStoryAction(Inline(ix)));
                        }
                        return menu;
                    })
                    .submenu('Hunk separator', window, cx, (menu, _, _) -> {
                        for (ix in 0...SEPARATORS.length) {
                            menu = menu.menuWithCheck(SEPARATORS[ix].label, separator == ix, new DiffStoryAction(Separator(ix)));
                        }
                        return menu;
                    })
                    .submenu('Change indicator', window, cx, (menu, _, _) -> {
                        for (ix in 0...INDICATORS.length) {
                            menu = menu.menuWithCheck(INDICATORS[ix].label, indicator == ix, new DiffStoryAction(Indicator(ix)));
                        }
                        return menu;
                    })
                    .separator()
                    .menuWithCheck('Tint changed lines', background, new DiffStoryAction(Background))
                    .menuWithCheck('Highlight hovered line', hover, new DiffStoryAction(Hover))
                    .menuWithCheck('Wrap long lines', wrap, new DiffStoryAction(Wrap));
            }));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<DiffStory> = cast cx;
        final annotations = [for (comment in comments) DiffAnnotation.line(comment.id,
            new DiffLinePosition(comment.range.path(), comment.range.endSide(), comment.range.end()))];
        // The renderer receives `App`, so it reads a snapshot of the comments.
        final snapshot = [for (comment in comments) {id: comment.id, body: comment.body, resolved: comment.resolved}];
        final story:WeakEntity<DiffStory> = cast cx.weakEntity();
        final addStory = story;

        final diff = Diff.component(state)
            .wFull()
            .h(rems(32.))
            .hunkSeparator(SEPARATORS[separator].separator)
            .changeIndicator(INDICATORS[indicator].indicator)
            .changeBackground(background)
            .hoverHighlight(hover ? DiffHoverHighlight.Both : DiffHoverHighlight.None)
            .softWrap(wrap);
        if (example == 0) {
            // A diagnostic marks its line in place; the marker opens
            // application-owned details.
            final diagnostic = new DiffLinePosition('src/retry.rs', DiffSide.Modified, 21);
            diff.decorations([new DiffDecoration(new DiffLineRange('src/retry.rs', DiffSide.Modified, 21, 21))])
                .gutterMarkers([new DiffGutterMarker(ElementId.Name('overflow'), diagnostic).withLabel('Possible overflow')])
                .renderGutterMarker((marker, _, _) -> Button.component(marker.id())
                    .ghost()
                    .xsmall()
                    .icon(IconName.TriangleAlert)
                    .tooltip(marker.label())
                    .onClick((_, window, cx) -> {
                        window.pushNotification('2_u32.pow(attempt) overflows for attempts above 31', cx);
                    }))
                .annotations(annotations)
                .renderAnnotation((annotation, _, cx) -> {
                    var id = annotation.id();
                    var body = '';
                    var resolved = false;
                    for (entry in snapshot) {
                        if (entry.id.equals(annotation.id())) {
                            id = entry.id;
                            body = entry.body;
                            resolved = entry.resolved;
                            break;
                        }
                    }
                    final theme = Theme.global(cx);
                    final column = vFlex()
                        .wFull()
                        .gap2()
                        .child(hFlex()
                            .wFull()
                            .justifyBetween()
                            .gap2()
                            .child(hFlex()
                                .gap2()
                                .child(div()
                                    .textSm()
                                    .fontMedium()
                                    .child('Alex'))
                                .child(div()
                                    .textXs()
                                    .textColor(theme.mutedForeground)
                                    .child(resolved ? 'Resolved' : 'Review comment')))
                            .child(Button.component(id)
                                .wAuto()
                                .ghost()
                                .xsmall()
                                .label(resolved ? 'Reopen' : 'Resolve')
                                .onClick((_, _, cx) -> {
                                    if (story.isUpgradable()) story.update(cx, (this_:DiffStory, cx) -> {
                                        for (comment in this_.comments) {
                                            if (comment.id.equals(id)) {
                                                comment.resolved = !comment.resolved;
                                                break;
                                            }
                                        }
                                        cx.notify();
                                    });
                                })));
                    if (!resolved) {
                        column.child(div().textSm().child(body));
                    }
                    return column;
                })
                .onAddAnnotation((range, _, cx) -> {
                    if (addStory.isUpgradable()) addStory.update(cx, (this_:DiffStory, cx) -> this_.addComment(range, cx));
                });
        }

        return vFlex()
            .wFull()
            .gap3()
            .onAction(DiffStoryAction, self.listener((this_:DiffStory, action:DiffStoryAction, window, cx) -> this_.onDiffAction(action, window, cx)))
            .child(renderToolbar(self))
            .child(vFlex()
                .wFull()
                .gap2()
                .child(div().fontMedium().child(EXAMPLES[example]))
                .child(diff));
    }

    static function pad4(n:Int):String {
        return StringTools.lpad(Std.string(n), '0', 4);
    }

    static function exampleFiles(example:Int):Array<DiffFile> {
        final patch = switch example {
            case 1: ADDED_PATCH;
            case 2: DELETED_PATCH;
            case 3: UNICODE_PATCH;
            case 4:
                final prefix = 'const ENDPOINT: &str = "https://api.example.com/v1/changes?';
                final repeated = [for (_ in 0...24) 'scope=repository&'].join('');
                '--- a/src/endpoint.rs\n+++ b/src/endpoint.rs\n@@ -1 +1 @@\n-$prefix$repeated&limit=20";\n+$prefix$repeated&limit=100";\n';
            case 5:
                // The fixture is a supplied patch: no source comparison is performed.
                final patch = new StringBuf();
                patch.add('--- a/config/features.conf\n+++ b/config/features.conf\n@@ -1,5000 +1,5000 @@\n');
                for (line in 1...5001) {
                    switch line {
                        case 40 | 4960:
                            patch.add('-entry_${pad4(line)} = enabled\n+entry_${pad4(line)} = disabled\n');
                        case 2500:
                            patch.add('-entry_${pad4(line)} = enabled\n+entry_${pad4(line)} = pending\n');
                        case _:
                            patch.add(' entry_${pad4(line)} = enabled\n');
                    }
                }
                patch.toString();
            case 6: RENAMED_PATCH;
            case 7: NO_NEWLINE_PATCH;
            case 8: MODE_PATCH;
            case 9:
                return [DiffFile.parseConflicts('src/retry.rs', MERGE_CONFLICT)];
            case 10:
                return [DiffFile.unchanged('src/retry.rs', SOURCE_FILE)];
            // A pull request touches several files; they share one scrolling list.
            case _: REVIEW_PATCH + ADDED_PATCH + DELETED_PATCH + MODE_PATCH;
        }
        return DiffFile.parse(patch);
    }

    static final MERGE_CONFLICT:String = "impl Default for RetryPolicy {\n    fn default() -> Self {\n        Self {\n<<<<<<< HEAD\n            max_attempts: 5,\n            base_delay: Duration::from_millis(100),\n=======\n            max_attempts: 3,\n            base_delay: Duration::from_millis(250),\n>>>>>>> retry-backoff\n        }\n    }\n}\n";
    static final SOURCE_FILE:String = "use std::time::Duration;\n\n/// How often a failed request is retried.\npub struct RetryPolicy {\n    pub max_attempts: u32,\n    pub base_delay: Duration,\n}\n\nimpl RetryPolicy {\n    /// Returns the delay before the next attempt.\n    pub fn delay(&self, attempt: u32) -> Duration {\n        self.base_delay * 2_u32.pow(attempt.min(6))\n    }\n}\n";
    static final ADDED_PATCH:String = "diff --git a/src/retry.rs b/src/retry.rs\nnew file mode 100644\n--- /dev/null\n+++ b/src/retry.rs\n@@ -0,0 +1,3 @@\n+pub fn retry_delay(attempt: u32) -> u64 {\n+    100 * 2_u64.pow(attempt.min(6))\n+}\n";
    static final DELETED_PATCH:String = "diff --git a/src/legacy_retry.rs b/src/legacy_retry.rs\ndeleted file mode 100644\n--- a/src/legacy_retry.rs\n+++ /dev/null\n@@ -1,3 +0,0 @@\n-pub fn retry_delay(_: u32) -> u64 {\n-    1000\n-}\n";
    static final UNICODE_PATCH:String = "--- a/src/greeting.rs\n+++ b/src/greeting.rs\n@@ -1,6 +1,6 @@\n-// Greeting for every visitor\n+// 为每位访客生成问候\n fn greeting(name: &str) -> String {\n-\tformat!(\"Hello, {name} 👋\")\n+\tformat!(\"你好，{name} 🌏\")\n }\n \n-// café: é, 中文，مرحبا\n+// café: é, 中文，مرحبا\n";
    static final RENAMED_PATCH:String = "diff --git a/src/retry.rs b/src/retry_policy.rs\nsimilarity index 100%\nrename from src/retry.rs\nrename to src/retry_policy.rs\n";
    static final NO_NEWLINE_PATCH:String = "--- a/config/review.conf\n+++ b/config/review.conf\n@@ -1,2 +1,2 @@\n enabled=true\n-limit=20\n+limit=100\n\\ No newline at end of file\n";
    static final MODE_PATCH:String = "diff --git a/scripts/review.sh b/scripts/review.sh\nold mode 100644\nnew mode 100755\n";
    static final REVIEW_PATCH:String = "diff --git a/src/retry.rs b/src/retry.rs\nindex 30a471b..604db2a 100644\n--- a/src/retry.rs\n+++ b/src/retry.rs\n@@ -9,7 +9,7 @@ impl Default for RetryPolicy {\n impl Default for RetryPolicy {\n     fn default() -> Self {\n         Self {\n-            max_attempts: 3,\n+            max_attempts: 5,\n             base_delay: Duration::from_millis(100),\n         }\n     }\n@@ -18,7 +18,7 @@ impl RetryPolicy {\n impl RetryPolicy {\n     /// Returns the delay before the next attempt.\n     pub fn delay(&self, attempt: u32) -> Duration {\n-        self.base_delay * attempt\n+        self.base_delay * 2_u32.pow(attempt.min(6))\n     }\n \n     /// Whether another request may be attempted.\n@@ -29,4 +29,4 @@ impl RetryPolicy {\n \n pub fn describe(policy: &RetryPolicy) -> String {\n-    format!(\"{} attempts\", policy.max_attempts)\n+    format!(\"Up to {} attempts\", policy.max_attempts)\n }\n";

}
