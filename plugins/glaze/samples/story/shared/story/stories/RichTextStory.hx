// New page of the Haxe port (no gpui-kit equivalent): the rich text component of the kit, `RichText`.
// See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.FontWeight;
import glaze.IntoElement;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.StyleBuilder;
import glaze.TextAlign;
import glaze.UnderlineStyle;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.base.motion.Easing;
import glaze.kit.base.motion.Keyframes.Keyframe;
import glaze.kit.base.motion.MotionTransform;
import glaze.kit.base.motion.Stagger;
import glaze.kit.base.motion.Timing;
import glaze.kit.text.RichText;
import glaze.kit.text.RichText.RichSpan;
import glaze.kit.text.RichText.RichTextAnimation;
import glaze.kit.text.RichText.RichTextStyle;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class RichTextStory extends Model implements Story {

    public static function title():String {
        return 'Rich Text';
    }

    public static function description():String {
        return 'A paragraph of typed spans: mixed sizes, pills, spacing, case and animated text.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<RichTextStory> {
        return cx.newEntity((c:Context<RichTextStory>) -> new RichTextStory(window, c));
    }

    final focusHandle_:FocusHandle;

    function new(_:Window, cx:Context<RichTextStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    static inline function moved(x:Float, y:Float, rotation:Float = 0., opacity:Float = 1.):MotionTransform {
        return new MotionTransform(new Point(x, y), new Point(1., 1.), rotation, opacity);
    }

    /** Each character rises by an eighth of an em, one after the other. */
    static function wave():RichTextAnimation {
        return RichTextAnimation.of([
            new Keyframe(0., moved(0., 0.)),
            new Keyframe(0.5, moved(0., -0.12)),
            new Keyframe(1., moved(0., 0.)),
        ], new Timing(1.2).ease(Easing.EaseInOut).iterations(Infinite)).translationInEm().perCharacter(new Stagger(0.09, First), true);
    }

    /** The whole run shakes from side to side. */
    static function shake():RichTextAnimation {
        return RichTextAnimation.of([
            new Keyframe(0., moved(0., 0.)),
            new Keyframe(0.25, moved(-0.06, 0.)),
            new Keyframe(0.75, moved(0.06, 0.)),
            new Keyframe(1., moved(0., 0.)),
        ], new Timing(0.35).ease(Easing.Linear).iterations(Infinite)).translationInEm();
    }

    /** Each character trembles and turns by a degree. */
    static function rumble():RichTextAnimation {
        final degree = Math.PI / 180.;
        return RichTextAnimation.of([
            new Keyframe(0., moved(0., 0.)),
            new Keyframe(0.25, moved(0.02, -0.02, -degree)),
            new Keyframe(0.5, moved(-0.02, 0.02, degree)),
            new Keyframe(0.75, moved(0.02, 0.02, -degree)),
            new Keyframe(1., moved(0., 0.)),
        ], new Timing(0.16).ease(Easing.Linear).iterations(Infinite)).translationInEm().perCharacter(new Stagger(0.037, First), true);
    }

    /** The run fades out and in. */
    static function pulse():RichTextAnimation {
        return RichTextAnimation.of([
            new Keyframe(0., moved(0., 0.)),
            new Keyframe(0.5, moved(0., 0., 0., 0.45)),
            new Keyframe(1., moved(0., 0.)),
        ], new Timing(1.6).ease(Easing.EaseInOut).iterations(Infinite));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final bold = new RichTextStyle().fontWeight(FontWeight.BOLD);
        final muted = new RichTextStyle().color(theme.mutedForeground);
        final accent = new RichTextStyle().color(theme.primary).fontWeight(FontWeight.SEMIBOLD);
        final pill = new RichTextStyle()
            .fontSize(Relative(0.85))
            .color(theme.primary)
            .box(StyleBuilder.build(s -> s.px(px(6.)).py(px(1.)).mx(px(2.)).border1().borderColor(theme.primary.opacity(0.4)).bg(theme.primary.opacity(0.1)).rounded(px(9.))));
        final badge = new RichTextStyle()
            .fontSize(Relative(0.8))
            .fontWeight(FontWeight.BOLD)
            .color(theme.primaryForeground)
            .box(StyleBuilder.build(s -> s.px(px(5.)).mx(px(2.)).bg(theme.primary).rounded(px(3.))));

        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .child(section('Mixed styles')
                .description('Families, weights and sizes share one baseline; decorations, colors and opacity apply to a span.')
                .w(px(520.))
                .child(RichText.component('mixed').wFull().spans([
                    RichSpan.text('A paragraph can hold '),
                    RichSpan.text('bold', bold),
                    RichSpan.text(', '),
                    RichSpan.text('italic', new RichTextStyle().fontStyle(glaze.FontStyle.Italic)),
                    RichSpan.text(', '),
                    RichSpan.text('small', new RichTextStyle().fontSize(Relative(0.85))),
                    RichSpan.text(' and '),
                    RichSpan.text('big', new RichTextStyle().fontSize(Relative(1.6))),
                    RichSpan.text(' text, a size in pixels ('),
                    RichSpan.text('11 px', new RichTextStyle().fontSize(Absolute(11.))),
                    RichSpan.text('), '),
                    RichSpan.text('underlined', new RichTextStyle().underline(new UnderlineStyle(px(1.)))),
                    RichSpan.text(', '),
                    RichSpan.text('muted', muted),
                    RichSpan.text(' or '),
                    RichSpan.text('whispered', new RichTextStyle().fontStyle(glaze.FontStyle.Italic).opacity(0.65).fontSize(Relative(0.92))),
                    RichSpan.text(' words, and '),
                    RichSpan.text('a link', new RichTextStyle().color(theme.link).underline(new UnderlineStyle(px(1.))).link('https://ceramic-engine.com')),
                    RichSpan.text('.'),
                ])))
            .child(section('Pills and inline elements')
                .description('A boxed span has its own background, border, radius, padding and margin, and never breaks across lines.')
                .w(px(520.))
                .child(RichText.component('pills').wFull().spans([
                    RichSpan.text('Tags such as '),
                    RichSpan.box('happy', pill),
                    RichSpan.text(' or '),
                    RichSpan.box('NEW', badge),
                    RichSpan.text(' sit in the line, and so does any element: '),
                    RichSpan.element(Icon.component(IconName.Heart).size4().textColor(theme.primary)),
                    RichSpan.text(' an icon.'),
                ])))
            .child(section('Letter spacing and case')
                .description('Spacing in pixels or in em of the span, and upper, lower or capitalized text.')
                .w(px(520.))
                .child(RichText.component('spacing').wFull().spans([
                    RichSpan.text('shouted words', new RichTextStyle().textTransform(Uppercase).letterSpacing(Em(0.03)).fontWeight(FontWeight.BOLD)),
                    RichSpan.text(', '),
                    RichSpan.text('w i d e', new RichTextStyle().letterSpacing(Absolute(4.))),
                    RichSpan.text(', '),
                    RichSpan.text('a capitalized title', new RichTextStyle().textTransform(Capitalize)),
                    RichSpan.text(', '),
                    RichSpan.text('QUIET', new RichTextStyle().textTransform(Lowercase)),
                    RichSpan.text(' and '),
                    RichSpan.text('straße', new RichTextStyle().textTransform(Uppercase)),
                    RichSpan.text('.'),
                ])))
            .child(section('Alignment and white space')
                .description('Lines aligned in the width of the paragraph; white space collapsed or kept.')
                .w(px(520.))
                .child(vFlex()
                    .wFull()
                    .gap3()
                    .child(RichText.component('centered').wFull().textAlign(TextAlign.Center).spans([
                        RichSpan.text('Centered lines'),
                        RichSpan.lineBreak(),
                        RichSpan.text('of different widths', muted),
                    ]))
                    .child(RichText.component('right').wFull().textAlign(TextAlign.Right).spans([RichSpan.text('Aligned to the right')]))
                    .child(RichText.component('pre').wFull().whiteSpace(PreWrap).fontFamily(theme.monoFontFamily).spans([
                        RichSpan.text('kept:   three spaces\n  and an indented line'),
                    ]))))
            .child(section('Animated text')
                .description('Keyframes and a timing, for a whole span or for each of its characters. The paragraph is not laid out again.')
                .w(px(520.))
                .child(RichText.component('animated').wFull().textSize(px(18.)).spans([
                    RichSpan.text('A '),
                    RichSpan.text('waving word', accent.merge(new RichTextStyle().animation(wave()))),
                    RichSpan.text(', a '),
                    RichSpan.text('shaking run', accent.merge(new RichTextStyle().animation(shake()))),
                    RichSpan.text(', a '),
                    RichSpan.text('rumbling', accent.merge(new RichTextStyle().animation(rumble()))),
                    RichSpan.text(' word, a '),
                    RichSpan.text('pulsing run', accent.merge(new RichTextStyle().animation(pulse()))),
                    RichSpan.text(' and a '),
                    RichSpan.box('shaking pill', pill.merge(new RichTextStyle().animation(shake()))),
                    RichSpan.text('.'),
                ])));
    }

}
