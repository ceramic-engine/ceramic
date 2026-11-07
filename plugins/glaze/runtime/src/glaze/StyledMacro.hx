// Ported from gpui-pre-macros 0.3.10: src/styles.rs (tables and generators of the
// style helper methods) and gpui-pre 0.3.10: src/styled.rs (hand written methods)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust procedural macros to a Haxe build macro for Ceramic. See NOTICE.md.
package gpui;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using StringTools;

private typedef BoxPrefix = {
    prefix:String,
    autoAllowed:Bool,
    fields:Array<String>
}

private typedef Suffix = {
    suffix:String,
    /** `px:<value>`, `rems:<value>`, `relative:<value>` or `auto` */
    value:String
}
#end

/**
 * Generates the fluent style methods of `Styled` (GPUI's `gpui_macros`
 * `style_helpers!`, `margin_style_methods!`... plus the methods written by
 * hand in `styled.rs`), and the shared length constants of `StyledValues`.
 *
 * Every class implementing `Styled` gets about 900 `extern inline` methods
 * returning the class itself: they produce no code of their own, each call
 * site is inlined into a field assignment on `style()`. Lengths of the
 * predefined scales are shared constants (`StyledValues`), so calling
 * `gap2()` allocates nothing.
 *
 * Names are converted to camelCase: `gap_2` -> `gap2`, `px_0p5` -> `px0p5`,
 * `w_full` -> `wFull`, `m_neg_2` -> `mNeg2`, `rounded_md` -> `roundedMd`.
 * An underscore is kept between two numbers: `w_1_2` -> `w1_2`.
 */
class StyledMacro {

    /**
     * Converts a Rust method name to camelCase, keeping an underscore between two numbers.
     */
    public static function camelCase(name:String):String {
        final parts = name.split('_');
        var result = parts[0];
        for (i in 1...parts.length) {
            final part = parts[i];
            if (part.length == 0)
                continue;
            final first = part.charCodeAt(0);
            final isDigit = first >= '0'.code && first <= '9'.code;
            if (isDigit) {
                final last = result.charCodeAt(result.length - 1);
                if (last >= '0'.code && last <= '9'.code) {
                    result += '_' + part;
                }
                else {
                    result += part;
                }
            }
            else {
                result += part.charAt(0).toUpperCase() + part.substr(1);
            }
        }
        return result;
    }

    #if macro

    static function boxStyleSuffixes():Array<Suffix> {
        return [
            {suffix: '0', value: 'px:0.0'},
            {suffix: '0p5', value: 'rems:0.125'},
            {suffix: '1', value: 'rems:0.25'},
            {suffix: '1p5', value: 'rems:0.375'},
            {suffix: '2', value: 'rems:0.5'},
            {suffix: '2p5', value: 'rems:0.625'},
            {suffix: '3', value: 'rems:0.75'},
            {suffix: '3p5', value: 'rems:0.875'},
            {suffix: '4', value: 'rems:1.0'},
            {suffix: '5', value: 'rems:1.25'},
            {suffix: '6', value: 'rems:1.5'},
            {suffix: '7', value: 'rems:1.75'},
            {suffix: '8', value: 'rems:2.0'},
            {suffix: '9', value: 'rems:2.25'},
            {suffix: '10', value: 'rems:2.5'},
            {suffix: '11', value: 'rems:2.75'},
            {suffix: '12', value: 'rems:3.0'},
            {suffix: '16', value: 'rems:4.0'},
            {suffix: '20', value: 'rems:5.0'},
            {suffix: '24', value: 'rems:6.0'},
            {suffix: '32', value: 'rems:8.0'},
            {suffix: '40', value: 'rems:10.0'},
            {suffix: '48', value: 'rems:12.0'},
            {suffix: '56', value: 'rems:14.0'},
            {suffix: '64', value: 'rems:16.0'},
            {suffix: '72', value: 'rems:18.0'},
            {suffix: '80', value: 'rems:20.0'},
            {suffix: '96', value: 'rems:24.0'},
            {suffix: '112', value: 'rems:28.0'},
            {suffix: '128', value: 'rems:32.0'},
            {suffix: 'auto', value: 'auto'},
            {suffix: 'px', value: 'px:1.0'},
            {suffix: 'full', value: 'relative:1.0'},
            {suffix: '1_2', value: 'relative:0.5'},
            {suffix: '1_3', value: 'relative:(1.0 / 3.0)'},
            {suffix: '2_3', value: 'relative:(2.0 / 3.0)'},
            {suffix: '1_4', value: 'relative:0.25'},
            {suffix: '2_4', value: 'relative:0.5'},
            {suffix: '3_4', value: 'relative:0.75'},
            {suffix: '1_5', value: 'relative:0.2'},
            {suffix: '2_5', value: 'relative:0.4'},
            {suffix: '3_5', value: 'relative:0.6'},
            {suffix: '4_5', value: 'relative:0.8'},
            {suffix: '1_6', value: 'relative:(1.0 / 6.0)'},
            {suffix: '5_6', value: 'relative:(5.0 / 6.0)'},
            {suffix: '1_12', value: 'relative:(1.0 / 12.0)'}
        ];
    }

    static function cornerSuffixes():Array<Suffix> {
        return [
            {suffix: 'none', value: 'px:0.0'},
            {suffix: 'xs', value: 'rems:0.125'},
            {suffix: 'sm', value: 'rems:0.25'},
            {suffix: 'md', value: 'rems:0.375'},
            {suffix: 'lg', value: 'rems:0.5'},
            {suffix: 'xl', value: 'rems:0.75'},
            {suffix: '2xl', value: 'rems:1.0'},
            {suffix: '3xl', value: 'rems:1.5'},
            {suffix: 'full', value: 'px:9999.0'}
        ];
    }

    static function borderSuffixes():Array<Suffix> {
        return [for (w in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 16, 20, 24, 32]) {suffix: '$w', value: 'px:$w.0'}];
    }

    static function marginPrefixes():Array<BoxPrefix> {
        return [
            {prefix: 'm', autoAllowed: true, fields: ['marginTop', 'marginBottom', 'marginLeft', 'marginRight']},
            {prefix: 'mt', autoAllowed: true, fields: ['marginTop']},
            {prefix: 'mb', autoAllowed: true, fields: ['marginBottom']},
            {prefix: 'my', autoAllowed: true, fields: ['marginTop', 'marginBottom']},
            {prefix: 'mx', autoAllowed: true, fields: ['marginLeft', 'marginRight']},
            {prefix: 'ml', autoAllowed: true, fields: ['marginLeft']},
            {prefix: 'mr', autoAllowed: true, fields: ['marginRight']}
        ];
    }

    static function paddingPrefixes():Array<BoxPrefix> {
        return [
            {prefix: 'p', autoAllowed: false, fields: ['paddingTop', 'paddingBottom', 'paddingLeft', 'paddingRight']},
            {prefix: 'pt', autoAllowed: false, fields: ['paddingTop']},
            {prefix: 'pb', autoAllowed: false, fields: ['paddingBottom']},
            {prefix: 'px', autoAllowed: false, fields: ['paddingLeft', 'paddingRight']},
            {prefix: 'py', autoAllowed: false, fields: ['paddingTop', 'paddingBottom']},
            {prefix: 'pl', autoAllowed: false, fields: ['paddingLeft']},
            {prefix: 'pr', autoAllowed: false, fields: ['paddingRight']}
        ];
    }

    static function positionPrefixes():Array<BoxPrefix> {
        return [
            {prefix: 'inset', autoAllowed: true, fields: ['insetTop', 'insetRight', 'insetBottom', 'insetLeft']},
            {prefix: 'top', autoAllowed: true, fields: ['insetTop']},
            {prefix: 'bottom', autoAllowed: true, fields: ['insetBottom']},
            {prefix: 'left', autoAllowed: true, fields: ['insetLeft']},
            {prefix: 'right', autoAllowed: true, fields: ['insetRight']}
        ];
    }

    static function boxPrefixes():Array<BoxPrefix> {
        return [
            {prefix: 'w', autoAllowed: true, fields: ['sizeWidth']},
            {prefix: 'h', autoAllowed: true, fields: ['sizeHeight']},
            {prefix: 'size', autoAllowed: true, fields: ['sizeWidth', 'sizeHeight']},
            {prefix: 'min_size', autoAllowed: true, fields: ['minSizeWidth', 'minSizeHeight']},
            {prefix: 'min_w', autoAllowed: true, fields: ['minSizeWidth']},
            {prefix: 'min_h', autoAllowed: true, fields: ['minSizeHeight']},
            {prefix: 'max_size', autoAllowed: true, fields: ['maxSizeWidth', 'maxSizeHeight']},
            {prefix: 'max_w', autoAllowed: true, fields: ['maxSizeWidth']},
            {prefix: 'max_h', autoAllowed: true, fields: ['maxSizeHeight']},
            {prefix: 'gap', autoAllowed: false, fields: ['gapWidth', 'gapHeight']},
            {prefix: 'gap_x', autoAllowed: false, fields: ['gapWidth']},
            {prefix: 'gap_y', autoAllowed: false, fields: ['gapHeight']}
        ];
    }

    static function cornerPrefixes():Array<BoxPrefix> {
        return [
            {prefix: 'rounded', autoAllowed: false, fields: ['cornerRadiusTopLeft', 'cornerRadiusTopRight', 'cornerRadiusBottomRight', 'cornerRadiusBottomLeft']},
            {prefix: 'rounded_t', autoAllowed: false, fields: ['cornerRadiusTopLeft', 'cornerRadiusTopRight']},
            {prefix: 'rounded_b', autoAllowed: false, fields: ['cornerRadiusBottomLeft', 'cornerRadiusBottomRight']},
            {prefix: 'rounded_r', autoAllowed: false, fields: ['cornerRadiusTopRight', 'cornerRadiusBottomRight']},
            {prefix: 'rounded_l', autoAllowed: false, fields: ['cornerRadiusTopLeft', 'cornerRadiusBottomLeft']},
            {prefix: 'rounded_tl', autoAllowed: false, fields: ['cornerRadiusTopLeft']},
            {prefix: 'rounded_tr', autoAllowed: false, fields: ['cornerRadiusTopRight']},
            {prefix: 'rounded_bl', autoAllowed: false, fields: ['cornerRadiusBottomLeft']},
            {prefix: 'rounded_br', autoAllowed: false, fields: ['cornerRadiusBottomRight']}
        ];
    }

    static function borderPrefixes():Array<BoxPrefix> {
        return [
            {prefix: 'border', autoAllowed: false, fields: ['borderWidthTop', 'borderWidthRight', 'borderWidthBottom', 'borderWidthLeft']},
            {prefix: 'border_t', autoAllowed: false, fields: ['borderWidthTop']},
            {prefix: 'border_b', autoAllowed: false, fields: ['borderWidthBottom']},
            {prefix: 'border_r', autoAllowed: false, fields: ['borderWidthRight']},
            {prefix: 'border_l', autoAllowed: false, fields: ['borderWidthLeft']},
            {prefix: 'border_x', autoAllowed: false, fields: ['borderWidthLeft', 'borderWidthRight']},
            {prefix: 'border_y', autoAllowed: false, fields: ['borderWidthTop', 'borderWidthBottom']}
        ];
    }

    /** Target type of a length constant */
    static inline final LENGTH = 'LENGTH';
    static inline final DEFINITE = 'DEFINITE';
    static inline final ABSOLUTE = 'ABSOLUTE';

    static function constantName(kind:String, scale:String, suffix:String, negate:Bool):String {
        return kind + '_' + scale + (negate ? '_NEG_' : '_') + suffix.toUpperCase();
    }

    /**
     * Haxe expression (source) of a scale value converted to the given kind.
     */
    static function valueSource(kind:String, value:String, negate:Bool):String {
        if (value == 'auto') {
            return 'gpui.Length.Auto';
        }
        final colon = value.indexOf(':');
        final unit = value.substr(0, colon);
        var number = value.substr(colon + 1);
        if (number.indexOf('.') == -1 && number.indexOf('e') == -1) number += '.0';
        final n = negate ? '-' + number : number;
        final absolute = switch unit {
            case 'px': 'gpui.AbsoluteLength.Pixels($n)';
            case 'rems': 'gpui.AbsoluteLength.Rems($n)';
            case _: null;
        }
        final definite = absolute != null ? 'gpui.DefiniteLength.Absolute($absolute)' : 'gpui.DefiniteLength.Fraction($n)';
        return switch kind {
            case 'ABSOLUTE': absolute;
            case 'DEFINITE': definite;
            case _: 'gpui.Length.Definite($definite)';
        }
    }

    static function typeOfKind(kind:String):ComplexType {
        return switch kind {
            case 'ABSOLUTE': macro :gpui.AbsoluteLength;
            case 'DEFINITE': macro :gpui.DefiniteLength;
            case _: macro :gpui.Length;
        }
    }

    /**
     * Build macro of `StyledValues`: one static constant per scale value and target type.
     */
    public static function buildValues():Array<Field> {
        final fields = Context.getBuildFields();
        final pos = Context.currentPos();
        final added = new Map<String, Bool>();

        function add(kind:String, scale:String, suffix:Suffix, negate:Bool):Void {
            final name = constantName(kind, scale, suffix.suffix, negate);
            if (added.exists(name))
                return;
            added.set(name, true);
            fields.push({
                name: name,
                access: [APublic, AStatic, AFinal],
                kind: FVar(typeOfKind(kind), Context.parseInlineString(valueSource(kind, suffix.value, negate), pos)),
                pos: pos
            });
        }

        for (suffix in boxStyleSuffixes()) {
            for (kind in [LENGTH, DEFINITE]) {
                if (suffix.value == 'auto' && kind != LENGTH)
                    continue;
                add(kind, 'BOX', suffix, false);
                if (suffix.value != 'auto') {
                    add(kind, 'BOX', suffix, true);
                }
            }
        }
        for (suffix in cornerSuffixes()) {
            add(ABSOLUTE, 'CORNER', suffix, false);
        }
        for (suffix in borderSuffixes()) {
            add(ABSOLUTE, 'BORDER', suffix, false);
        }

        return fields;
    }

    /**
     * Auto build macro of `Styled`: adds the fluent style methods to the class.
     */
    public static function build():Array<Field> {
        final fields = Context.getBuildFields();
        final localClass = Context.getLocalClass().get();
        final pos = Context.currentPos();

        // Only the first class of a hierarchy implementing Styled gets the methods
        var parent = localClass.superClass;
        while (parent != null) {
            final parentClass = parent.t.get();
            if (implementsStyled(parentClass))
                return null;
            parent = parentClass.superClass;
        }
        if (localClass.isInterface)
            return null;

        final existing = new Map<String, Bool>();
        for (field in fields) existing.set(field.name, true);

        final selfType:ComplexType = TPath({
            pack: localClass.pack,
            name: localClass.module.split('.').pop() == localClass.name ? localClass.name : localClass.module.split('.').pop(),
            sub: localClass.module.split('.').pop() == localClass.name ? null : localClass.name,
            params: [for (param in localClass.params) TPType(TPath({pack: [], name: param.name}))]
        });

        function addMethod(name:String, args:Array<FunctionArg>, body:String, ?doc:String):Void {
            if (existing.exists(name))
                return;
            existing.set(name, true);
            final expr = Context.parseInlineString('{ final style:gpui.StyleRefinement = this.style(); ' + body + ' return this; }', pos);
            fields.push({
                name: name,
                doc: doc,
                access: [APublic, AExtern, AInline],
                kind: FFun({args: args, ret: selfType, expr: expr}),
                pos: pos
            });
        }

        function arg(name:String, type:ComplexType):FunctionArg {
            return {name: name, type: type};
        }

        // Generated setters (gpui_macros)

        function boxMethods(prefixes:Array<BoxPrefix>, suffixes:Array<Suffix>, scale:String, customType:String):Void {
            for (prefix in prefixes) {
                final kind = customType == 'auto' ? (prefix.autoAllowed ? LENGTH : DEFINITE) : customType;
                final intoType = switch kind {
                    case 'ABSOLUTE': macro :gpui.IntoAbsoluteLength;
                    case 'DEFINITE': macro :gpui.IntoDefiniteLength;
                    case _: macro :gpui.IntoLength;
                }
                final fieldType = switch kind {
                    case 'ABSOLUTE': 'gpui.AbsoluteLength';
                    case 'DEFINITE': 'gpui.DefiniteLength';
                    case _: 'gpui.Length';
                }
                // Custom value setter
                var body = 'final value:$fieldType = length; ';
                for (field in prefix.fields) body += 'style.$field = value; ';
                addMethod(camelCase(prefix.prefix), [arg('length', intoType)], body, 'Sets ${prefix.fields.join(", ")} to the given length.');

                for (suffix in suffixes) {
                    final isAuto = suffix.value == 'auto';
                    if (!isAuto || prefix.autoAllowed) {
                        var body = '';
                        for (field in prefix.fields) body += 'style.$field = gpui.StyledValues.${constantName(kind, scale, suffix.suffix, false)}; ';
                        addMethod(camelCase(prefix.prefix + '_' + suffix.suffix), [], body, 'Sets ${prefix.fields.join(", ")} to `${suffix.value}`.');
                    }
                    if (!isAuto && scale == 'BOX') {
                        var body = '';
                        for (field in prefix.fields) body += 'style.$field = gpui.StyledValues.${constantName(kind, scale, suffix.suffix, true)}; ';
                        addMethod(camelCase(prefix.prefix + '_neg_' + suffix.suffix), [], body, 'Sets ${prefix.fields.join(", ")} to `-${suffix.value}`.');
                    }
                }
            }
        }

        boxMethods(boxPrefixes(), boxStyleSuffixes(), 'BOX', 'auto');
        boxMethods(cornerPrefixes(), cornerSuffixes(), 'CORNER', ABSOLUTE);
        boxMethods(marginPrefixes(), boxStyleSuffixes(), 'BOX', 'auto');
        boxMethods(paddingPrefixes(), boxStyleSuffixes(), 'BOX', 'auto');
        boxMethods(positionPrefixes(), boxStyleSuffixes(), 'BOX', 'auto');
        boxMethods(borderPrefixes(), borderSuffixes(), 'BORDER', ABSOLUTE);

        // visibility_style_methods!
        addMethod('visible', [], 'style.visibility = gpui.Visibility.Visible;', 'Sets the visibility of the element to `visible`.');
        addMethod('invisible', [], 'style.visibility = gpui.Visibility.Hidden;', 'Sets the visibility of the element to `hidden`.');

        // position_style_methods!
        addMethod('relative', [], 'style.position = gpui.Position.Relative;', 'Sets the position of the element to `relative`.');
        addMethod('absolute', [], 'style.position = gpui.Position.Absolute;', 'Sets the position of the element to `absolute`.');

        // overflow_style_methods!
        addMethod('overflowHidden', [], 'style.overflowX = gpui.Overflow.Hidden; style.overflowY = gpui.Overflow.Hidden;', 'Sets the behavior of content that overflows the container to be hidden.');
        addMethod('overflowXHidden', [], 'style.overflowX = gpui.Overflow.Hidden;', 'Sets the behavior of content that overflows the container on the X axis to be hidden.');
        addMethod('overflowYHidden', [], 'style.overflowY = gpui.Overflow.Hidden;', 'Sets the behavior of content that overflows the container on the Y axis to be hidden.');

        // cursor_style_methods!
        addMethod('cursor', [arg('cursor', macro :gpui.CursorStyle)], 'style.mouseCursor = cursor;', 'Set the cursor style when hovering over this element');
        for (entry in [
            ['default', 'Arrow'], ['pointer', 'PointingHand'], ['text', 'IBeam'], ['move', 'ClosedHand'],
            ['not_allowed', 'OperationNotAllowed'], ['context_menu', 'ContextualMenu'], ['crosshair', 'Crosshair'],
            ['vertical_text', 'IBeamCursorForVerticalLayout'], ['alias', 'DragLink'], ['copy', 'DragCopy'],
            ['no_drop', 'OperationNotAllowed'], ['grab', 'OpenHand'], ['grabbing', 'ClosedHand'],
            ['ew_resize', 'ResizeLeftRight'], ['ns_resize', 'ResizeUpDown'], ['nesw_resize', 'ResizeUpRightDownLeft'],
            ['nwse_resize', 'ResizeUpLeftDownRight'], ['col_resize', 'ResizeColumn'], ['row_resize', 'ResizeRow'],
            ['n_resize', 'ResizeUp'], ['e_resize', 'ResizeRight'], ['s_resize', 'ResizeDown'], ['w_resize', 'ResizeLeft']
        ]) {
            addMethod(camelCase('cursor_' + entry[0]), [], 'style.mouseCursor = gpui.CursorStyle.${entry[1]};', 'Sets the cursor style when hovering an element to `${entry[0]}`.');
        }

        // border_style_methods!
        addMethod('borderColor', [arg('borderColor', macro :gpui.IntoHsla)], 'style.borderColor = borderColor;', 'Sets the border color of the element.');

        // box_shadow_style_methods!
        addMethod('shadow', [arg('shadows', macro :Array<gpui.BoxShadow>)], 'style.boxShadow = shadows;', 'Sets the box shadow of the element.');
        addMethod('shadowNone', [], 'style.boxShadow = [];', 'Clears the box shadow of the element.');
        // Preset values are in `StyledValues.SHADOW_PRESETS`
        for (preset in ['2xs', 'xs', 'sm', 'md', 'lg', 'xl', '2xl']) {
            addMethod(camelCase('shadow_' + preset), [], 'style.boxShadow = gpui.StyledValues.shadowPreset("$preset");', 'Sets the box shadow of the element (`shadow-$preset`).');
        }

        // styled.rs
        final hand:Array<Array<String>> = [
            ['block', '', 'style.display = gpui.Display.Block;'],
            ['flex', '', 'style.display = gpui.Display.Flex;'],
            ['grid', '', 'style.display = gpui.Display.Grid;'],
            ['hidden', '', 'style.display = gpui.Display.None;'],
            ['whitespaceNormal', '', 'style.textStyle().whiteSpace = gpui.WhiteSpace.Normal;'],
            ['whitespaceNowrap', '', 'style.textStyle().whiteSpace = gpui.WhiteSpace.Nowrap;'],
            ['textEllipsis', '', 'style.textStyle().textOverflow = gpui.TextOverflow.Truncate(gpui.StyledValues.ELLIPSIS);'],
            ['textEllipsisStart', '', 'style.textStyle().textOverflow = gpui.TextOverflow.TruncateStart(gpui.StyledValues.ELLIPSIS);'],
            ['textEllipsisMiddle', '', 'style.textStyle().textOverflow = gpui.TextOverflow.TruncateMiddle(gpui.StyledValues.ELLIPSIS);'],
            ['textLeft', '', 'style.textStyle().textAlign = gpui.TextAlign.Left;'],
            ['textCenter', '', 'style.textStyle().textAlign = gpui.TextAlign.Center;'],
            ['textRight', '', 'style.textStyle().textAlign = gpui.TextAlign.Right;'],
            ['truncate', '', 'style.overflowX = gpui.Overflow.Hidden; style.overflowY = gpui.Overflow.Hidden; style.textStyle().whiteSpace = gpui.WhiteSpace.Nowrap; style.textStyle().textOverflow = gpui.TextOverflow.Truncate(gpui.StyledValues.ELLIPSIS);'],
            ['flexCol', '', 'style.flexDirection = gpui.FlexDirection.Column;'],
            ['flexColReverse', '', 'style.flexDirection = gpui.FlexDirection.ColumnReverse;'],
            ['flexRow', '', 'style.flexDirection = gpui.FlexDirection.Row;'],
            ['flexRowReverse', '', 'style.flexDirection = gpui.FlexDirection.RowReverse;'],
            ['flex1', '', 'style.flexGrow = 1.0; style.flexShrink = 1.0; style.flexBasis = gpui.StyledValues.LENGTH_RELATIVE_ZERO;'],
            ['flexAuto', '', 'style.flexGrow = 1.0; style.flexShrink = 1.0; style.flexBasis = gpui.Length.Auto;'],
            ['flexInitial', '', 'style.flexGrow = 0.0; style.flexShrink = 1.0; style.flexBasis = gpui.Length.Auto;'],
            ['flexNone', '', 'style.flexGrow = 0.0; style.flexShrink = 0.0; style.flexBasis = gpui.Length.Auto;'],
            ['flexGrow0', '', 'style.flexGrow = 0.0;'],
            ['flexGrow1', '', 'style.flexGrow = 1.0;'],
            ['flexShrink0', '', 'style.flexShrink = 0.0;'],
            ['flexShrink1', '', 'style.flexShrink = 1.0;'],
            ['flexWrap', '', 'style.flexWrap = gpui.FlexWrap.Wrap;'],
            ['flexWrapReverse', '', 'style.flexWrap = gpui.FlexWrap.WrapReverse;'],
            ['flexNowrap', '', 'style.flexWrap = gpui.FlexWrap.NoWrap;'],
            ['itemsStart', '', 'style.alignItems = gpui.AlignItems.FlexStart;'],
            ['itemsEnd', '', 'style.alignItems = gpui.AlignItems.FlexEnd;'],
            ['itemsCenter', '', 'style.alignItems = gpui.AlignItems.Center;'],
            ['itemsBaseline', '', 'style.alignItems = gpui.AlignItems.Baseline;'],
            ['itemsStretch', '', 'style.alignItems = gpui.AlignItems.Stretch;'],
            ['selfStart', '', 'style.alignSelf = gpui.AlignItems.Start;'],
            ['selfEnd', '', 'style.alignSelf = gpui.AlignItems.End;'],
            ['selfFlexStart', '', 'style.alignSelf = gpui.AlignItems.FlexStart;'],
            ['selfFlexEnd', '', 'style.alignSelf = gpui.AlignItems.FlexEnd;'],
            ['selfCenter', '', 'style.alignSelf = gpui.AlignItems.Center;'],
            ['selfBaseline', '', 'style.alignSelf = gpui.AlignItems.Baseline;'],
            ['selfStretch', '', 'style.alignSelf = gpui.AlignItems.Stretch;'],
            ['justifyStart', '', 'style.justifyContent = gpui.AlignContent.Start;'],
            ['justifyEnd', '', 'style.justifyContent = gpui.AlignContent.End;'],
            ['justifyCenter', '', 'style.justifyContent = gpui.AlignContent.Center;'],
            ['justifyBetween', '', 'style.justifyContent = gpui.AlignContent.SpaceBetween;'],
            ['justifyAround', '', 'style.justifyContent = gpui.AlignContent.SpaceAround;'],
            ['justifyEvenly', '', 'style.justifyContent = gpui.AlignContent.SpaceEvenly;'],
            ['contentNormal', '', 'style.unset(gpui.StyleRefinement.ALIGN_CONTENT);'],
            ['contentCenter', '', 'style.alignContent = gpui.AlignContent.Center;'],
            ['contentStart', '', 'style.alignContent = gpui.AlignContent.FlexStart;'],
            ['contentEnd', '', 'style.alignContent = gpui.AlignContent.FlexEnd;'],
            ['contentBetween', '', 'style.alignContent = gpui.AlignContent.SpaceBetween;'],
            ['contentAround', '', 'style.alignContent = gpui.AlignContent.SpaceAround;'],
            ['contentEvenly', '', 'style.alignContent = gpui.AlignContent.SpaceEvenly;'],
            ['contentStretch', '', 'style.alignContent = gpui.AlignContent.Stretch;'],
            ['aspectSquare', '', 'style.aspectRatio = 1.0;'],
            ['borderDashed', '', 'style.borderStyle = gpui.scene.BorderStyle.Dashed;'],
            ['textXs', '', 'style.textStyle().fontSize = gpui.StyledValues.TEXT_XS;'],
            ['textSm', '', 'style.textStyle().fontSize = gpui.StyledValues.TEXT_SM;'],
            ['textBase', '', 'style.textStyle().fontSize = gpui.StyledValues.TEXT_BASE;'],
            ['textLg', '', 'style.textStyle().fontSize = gpui.StyledValues.TEXT_LG;'],
            ['textXl', '', 'style.textStyle().fontSize = gpui.StyledValues.TEXT_XL;'],
            ['text2xl', '', 'style.textStyle().fontSize = gpui.StyledValues.TEXT_2XL;'],
            ['text3xl', '', 'style.textStyle().fontSize = gpui.StyledValues.TEXT_3XL;'],
            ['italic', '', 'style.textStyle().fontStyle = gpui.FontStyle.Italic;'],
            ['notItalic', '', 'style.textStyle().fontStyle = gpui.FontStyle.Normal;'],
            ['underline', '', 'style.textStyle().underline = new gpui.UnderlineStyle(1.0);'],
            ['lineThrough', '', 'style.textStyle().strikethrough = new gpui.StrikethroughStyle(1.0);'],
            ['textDecorationNone', '', 'style.textStyle().underline = null;'],
            ['textDecorationSolid', '', 'gpui.StyledValues.underlineOf(style).wavy = false;'],
            ['textDecorationWavy', '', 'gpui.StyledValues.underlineOf(style).wavy = true;'],
            ['textDecoration0', '', 'gpui.StyledValues.underlineOf(style).thickness = 0.0;'],
            ['textDecoration1', '', 'gpui.StyledValues.underlineOf(style).thickness = 1.0;'],
            ['textDecoration2', '', 'gpui.StyledValues.underlineOf(style).thickness = 2.0;'],
            ['textDecoration4', '', 'gpui.StyledValues.underlineOf(style).thickness = 4.0;'],
            ['textDecoration8', '', 'gpui.StyledValues.underlineOf(style).thickness = 8.0;'],
            ['colStartAuto', '', 'style.gridLocationMut().columnStart = gpui.GridPlacement.Auto;'],
            ['colEndAuto', '', 'style.gridLocationMut().columnEnd = gpui.GridPlacement.Auto;'],
            ['colSpanFull', '', 'final location = style.gridLocationMut(); location.columnStart = gpui.GridPlacement.Line(1); location.columnEnd = gpui.GridPlacement.Line(-1);'],
            ['rowStartAuto', '', 'style.gridLocationMut().rowStart = gpui.GridPlacement.Auto;'],
            ['rowEndAuto', '', 'style.gridLocationMut().rowEnd = gpui.GridPlacement.Auto;'],
            ['rowSpanFull', '', 'final location = style.gridLocationMut(); location.rowStart = gpui.GridPlacement.Line(1); location.rowEnd = gpui.GridPlacement.Line(-1);'],
            ['debug', '', 'style.debug = true;'],
            ['debugBelow', '', 'style.debugBelow = true;']
        ];
        for (entry in hand) {
            addMethod(entry[0], [], entry[2]);
        }

        final handWithArgs:Array<{name:String, args:Array<FunctionArg>, body:String}> = [
            {name: 'scrollbarWidth', args: [arg('width', macro :gpui.IntoAbsoluteLength)], body: 'style.scrollbarWidth = width;'},
            {name: 'textOverflow', args: [arg('overflow', macro :gpui.TextOverflow)], body: 'style.textStyle().textOverflow = overflow;'},
            {name: 'textAlign', args: [arg('align', macro :gpui.TextAlign)], body: 'style.textStyle().textAlign = align;'},
            {name: 'lineClamp', args: [arg('lines', macro :Int)], body: 'style.textStyle().lineClamp = lines; style.overflowX = gpui.Overflow.Hidden; style.overflowY = gpui.Overflow.Hidden;'},
            {name: 'flexBasis', args: [arg('basis', macro :gpui.IntoLength)], body: 'style.flexBasis = basis;'},
            {name: 'flexGrow', args: [arg('grow', macro :Float)], body: 'style.flexGrow = grow;'},
            {name: 'flexShrink', args: [arg('shrink', macro :Float)], body: 'style.flexShrink = shrink;'},
            {name: 'aspectRatio', args: [arg('ratio', macro :Float)], body: 'style.aspectRatio = ratio;'},
            {name: 'bg', args: [arg('fill', macro :gpui.IntoBackground)], body: 'style.background = fill;'},
            {name: 'textColor', args: [arg('color', macro :gpui.IntoHsla)], body: 'style.textStyle().color = color;'},
            {name: 'fontWeight', args: [arg('weight', macro :gpui.FontWeight)], body: 'style.textStyle().fontWeight = weight;'},
            {name: 'textBg', args: [arg('bg', macro :gpui.IntoHsla)], body: 'style.textStyle().backgroundColor = bg;'},
            {name: 'textSize', args: [arg('size', macro :gpui.IntoAbsoluteLength)], body: 'style.textStyle().fontSize = size;'},
            {name: 'textDecorationColor', args: [arg('color', macro :gpui.IntoHsla)], body: 'gpui.StyledValues.underlineOf(style).color = color;'},
            {name: 'fontFamily', args: [arg('familyName', macro :String)], body: 'style.textStyle().fontFamily = familyName;'},
            {name: 'lineHeight', args: [arg('lineHeight', macro :gpui.IntoDefiniteLength)], body: 'style.textStyle().lineHeight = lineHeight;'},
            {name: 'opacity', args: [arg('opacity', macro :Float)], body: 'style.opacity = opacity;'},
            {name: 'gridCols', args: [arg('cols', macro :Int)], body: 'style.gridCols = new gpui.GridTemplate(cols, gpui.GridTemplateMinSize.Zero);'},
            {name: 'gridColsMinContent', args: [arg('cols', macro :Int)], body: 'style.gridCols = new gpui.GridTemplate(cols, gpui.GridTemplateMinSize.MinContent);'},
            {name: 'gridColsMaxContent', args: [arg('cols', macro :Int)], body: 'style.gridCols = new gpui.GridTemplate(cols, gpui.GridTemplateMinSize.MaxContent);'},
            {name: 'gridRows', args: [arg('rows', macro :Int)], body: 'style.gridRows = new gpui.GridTemplate(rows, gpui.GridTemplateMinSize.Zero);'},
            {name: 'gridRowsMinContent', args: [arg('rows', macro :Int)], body: 'style.gridRows = new gpui.GridTemplate(rows, gpui.GridTemplateMinSize.MinContent);'},
            {name: 'gridRowsMaxContent', args: [arg('rows', macro :Int)], body: 'style.gridRows = new gpui.GridTemplate(rows, gpui.GridTemplateMinSize.MaxContent);'},
            {name: 'colStart', args: [arg('start', macro :Int)], body: 'style.gridLocationMut().columnStart = gpui.GridPlacement.Line(start);'},
            {name: 'colEnd', args: [arg('end', macro :Int)], body: 'style.gridLocationMut().columnEnd = gpui.GridPlacement.Line(end);'},
            {name: 'colSpan', args: [arg('span', macro :Int)], body: 'final location = style.gridLocationMut(); location.columnStart = gpui.GridPlacement.Span(span); location.columnEnd = gpui.GridPlacement.Span(span);'},
            {name: 'rowStart', args: [arg('start', macro :Int)], body: 'style.gridLocationMut().rowStart = gpui.GridPlacement.Line(start);'},
            {name: 'rowEnd', args: [arg('end', macro :Int)], body: 'style.gridLocationMut().rowEnd = gpui.GridPlacement.Line(end);'},
            {name: 'rowSpan', args: [arg('span', macro :Int)], body: 'final location = style.gridLocationMut(); location.rowStart = gpui.GridPlacement.Span(span); location.rowEnd = gpui.GridPlacement.Span(span);'}
        ];
        for (entry in handWithArgs) {
            addMethod(entry.name, entry.args, entry.body);
        }

        // Rust `text_style(&mut self) -> &mut TextStyleRefinement` (not fluent)
        if (!existing.exists('textStyle')) {
            fields.push({
                name: 'textStyle',
                doc: 'Returns the text style refinement of this element, created on first use.',
                access: [APublic, AExtern, AInline],
                kind: FFun({args: [], ret: macro :gpui.TextStyleRefinement, expr: macro return this.style().textStyle()}),
                pos: pos
            });
        }

        return fields;
    }

    static function implementsStyled(cls:ClassType):Bool {
        for (iface in cls.interfaces) {
            final ifaceType = iface.t.get();
            if (ifaceType.pack.join('.') == 'gpui' && ifaceType.name == 'Styled')
                return true;
        }
        return false;
    }

    #end

}
