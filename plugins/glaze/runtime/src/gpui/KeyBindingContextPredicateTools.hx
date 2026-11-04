// Ported from gpui-pre 0.3.10: src/keymap/context.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.KeyBindingContextPredicate;
import gpui.KeyContext.ContextScanner;

/**
 * Methods of `KeyBindingContextPredicate`, attached with `@:using`.
 */
class KeyBindingContextPredicateTools {

    static inline final PRECEDENCE_CHILD = 1;

    static inline final PRECEDENCE_OR = 2;

    static inline final PRECEDENCE_AND = 3;

    static inline final PRECEDENCE_EQ = 4;

    static inline final PRECEDENCE_NOT = 5;

    /**
     * Parse a string in the same format as the keymap's context field.
     *
     * A basic equivalence check against a set of identifiers can performed by
     * simply writing a string:
     *
     * `StatusBar` -> A predicate that will match a context with the identifier `StatusBar`
     *
     * You can also specify a key-value pair:
     *
     * `mode == visible` -> A predicate that will match a context with the key `mode`
     *                      with the value `visible`
     *
     * And a logical operations combining these two checks:
     *
     * `StatusBar && mode == visible` -> A predicate that will match a context with the
     *                                   identifier `StatusBar` and the key `mode`
     *                                   with the value `visible`
     *
     * There is also a special child `>` operator that will match a predicate that is
     * below another predicate:
     *
     * `StatusBar > mode == visible` -> A predicate that will match a context identifier `StatusBar`
     *                                  and a child context that has the key `mode` with the
     *                                  value `visible`
     *
     * This syntax supports `!=`, `||` and `&&` as logical operators.
     * You can also preface an operation or check with a `!` to negate it.
     *
     * Throws a `haxe.Exception` with GPUI's error message on invalid input.
     */
    public static function parse(source:String):KeyBindingContextPredicate {
        final parser = new PredicateParser(source);
        parser.pos = ContextScanner.skipWhitespace(source, 0);
        final predicate = parser.parseExpr(0);
        if (parser.pos < source.length) {
            throw new haxe.Exception("unexpected character '" + PredicateParser.debugChar(source, parser.pos) + "'");
        }
        return predicate;
    }

    /**
     * Like `parse`, but returns null instead of throwing.
     */
    public static function tryParse(source:String):Null<KeyBindingContextPredicate> {
        try {
            return parse(source);
        }
        catch (e:haxe.Exception) {
            return null;
        }
    }

    /**
     * Find the deepest depth at which the predicate matches.
     */
    public static function depthOf(self:KeyBindingContextPredicate, contexts:Array<KeyContext>):Null<Int> {
        var depth = contexts.length;
        while (depth >= 0) {
            // `evalInner(self, contexts.slice(0, depth), contexts)` without the slice
            if (evalRange(self, contexts, 0, depth, 0, contexts.length)) {
                return depth;
            }
            depth--;
        }
        return null;
    }

    /**
     * Eval a predicate against a set of contexts, arranged from lowest to highest.
     */
    public static function eval(self:KeyBindingContextPredicate, contexts:Array<KeyContext>):Bool {
        return evalRange(self, contexts, 0, contexts.length, 0, contexts.length);
    }

    /**
     * `evalInner(self, contexts.slice(start, end), contexts.slice(allStart, allEnd))`
     * without the slices (Rust borrows sub-slices): the same evaluation on
     * index ranges of one array.
     */
    static function evalRange(self:KeyBindingContextPredicate, contexts:Array<KeyContext>, start:Int, end:Int, allStart:Int, allEnd:Int):Bool {
        if (end - start == 0) {
            return false;
        }
        final context = contexts[end - 1];
        return switch self {
            case Identifier(name):
                context.contains(name);
            case Equal(left, right):
                final value = context.get(left);
                value != null && value == right;
            case NotEqual(left, right):
                final value = context.get(left);
                value == null || value != right;
            case Not(pred):
                var result = true;
                for (i in 0...allEnd - allStart) {
                    if (evalRange(pred, contexts, allStart, allStart + i + 1, allStart, allEnd)) {
                        result = false;
                        break;
                    }
                }
                result;
            case Descendant(parent, child):
                var result = false;
                for (i in 0...end - start - 1) {
                    if (evalRange(parent, contexts, start, start + i + 1, allStart, allEnd)) {
                        final restStart = start + i + 1;
                        result = evalRange(child, contexts, restStart, end, restStart, end);
                        break;
                    }
                }
                result;
            case And(left, right):
                evalRange(left, contexts, start, end, allStart, allEnd) && evalRange(right, contexts, start, end, allStart, allEnd);
            case Or(left, right):
                evalRange(left, contexts, start, end, allStart, allEnd) || evalRange(right, contexts, start, end, allStart, allEnd);
        }
    }

    /**
     * Eval a predicate against a set of contexts, arranged from lowest to highest.
     */
    public static function evalInner(self:KeyBindingContextPredicate, contexts:Array<KeyContext>, allContexts:Array<KeyContext>):Bool {
        if (contexts.length == 0) {
            return false;
        }
        final context = contexts[contexts.length - 1];
        return switch self {
            case Identifier(name):
                context.contains(name);
            case Equal(left, right):
                final value = context.get(left);
                value != null && value == right;
            case NotEqual(left, right):
                final value = context.get(left);
                value == null || value != right;
            case Not(pred):
                var result = true;
                for (i in 0...allContexts.length) {
                    if (evalInner(pred, allContexts.slice(0, i + 1), allContexts)) {
                        result = false;
                        break;
                    }
                }
                result;
            // Workspace > Pane > Editor
            //
            // Pane > (Pane > Editor) // should match?
            // (Pane > Pane) > Editor // should not match?
            // Pane > !Workspace <-- should match?
            // !Workspace        <-- shouldn't match?
            case Descendant(parent, child):
                var result = false;
                for (i in 0...contexts.length - 1) {
                    // [Workspace >  Pane], [Editor]
                    if (evalInner(parent, contexts.slice(0, i + 1), allContexts)) {
                        final rest = contexts.slice(i + 1);
                        result = evalInner(child, rest, rest);
                        break;
                    }
                }
                result;
            case And(left, right):
                evalInner(left, contexts, allContexts) && evalInner(right, contexts, allContexts);
            case Or(left, right):
                evalInner(left, contexts, allContexts) || evalInner(right, contexts, allContexts);
        }
    }

    /**
     * Returns whether or not this predicate matches all possible contexts
     * matched by the other predicate.
     */
    public static function isSuperset(self:KeyBindingContextPredicate, other:KeyBindingContextPredicate):Bool {
        if (equals(self, other)) {
            return true;
        }

        switch self {
            case Or(left, right):
                return isSuperset(left, other) || isSuperset(right, other);
            case _:
        }

        return switch other {
            case Descendant(_, child): isSuperset(self, child);
            case And(left, right): isSuperset(self, left) || isSuperset(self, right);
            case Identifier(_): false;
            case Equal(_, _): false;
            case NotEqual(_, _): false;
            case Not(_): false;
            case Or(_, _): false;
        }
    }

    /**
     * Structural equality (Rust derived `PartialEq`).
     */
    public static function equals(self:KeyBindingContextPredicate, other:KeyBindingContextPredicate):Bool {
        if (self == null || other == null) return self == other;
        return switch [self, other] {
            case [Identifier(a), Identifier(b)]: a == b;
            case [Equal(a1, a2), Equal(b1, b2)]: a1 == b1 && a2 == b2;
            case [NotEqual(a1, a2), NotEqual(b1, b2)]: a1 == b1 && a2 == b2;
            case [Descendant(a1, a2), Descendant(b1, b2)]: equals(a1, b1) && equals(a2, b2);
            case [Not(a), Not(b)]: equals(a, b);
            case [And(a1, a2), And(b1, b2)]: equals(a1, b1) && equals(a2, b2);
            case [Or(a1, a2), Or(b1, b2)]: equals(a1, b1) && equals(a2, b2);
            case _: false;
        }
    }

    /**
     * Formats the predicate in the keymap syntax (Rust `Display`).
     */
    public static function toString(self:KeyBindingContextPredicate):String {
        return switch self {
            case Identifier(name): name;
            case Equal(left, right): '$left == $right';
            case NotEqual(left, right): '$left != $right';
            case Descendant(parent, child): toString(parent) + ' > ' + toString(child);
            case Not(pred):
                switch pred {
                    case Identifier(name): '!' + name;
                    case _: '!(' + toString(pred) + ')';
                }
            case And(_, _):
                fmtJoined(self, ' && ', true);
            case Or(_, _):
                fmtJoined(self, ' || ', false);
        }
    }

    static function fmtJoined(self:KeyBindingContextPredicate, separator:String, isAnd:Bool):String {
        final buf = new StringBuf();
        fmtJoinedInner(self, buf, separator, isAnd, [true]);
        return buf.toString();
    }

    static function fmtJoinedInner(node:KeyBindingContextPredicate, buf:StringBuf, separator:String, isAnd:Bool, first:Array<Bool>):Void {
        switch node {
            case And(left, right) if (isAnd):
                fmtJoinedInner(left, buf, separator, isAnd, first);
                fmtJoinedInner(right, buf, separator, isAnd, first);
            case Or(left, right) if (!isAnd):
                fmtJoinedInner(left, buf, separator, isAnd, first);
                fmtJoinedInner(right, buf, separator, isAnd, first);
            case _:
                if (!first[0]) {
                    buf.add(separator);
                }
                first[0] = false;

                final needsParens = switch node {
                    case Or(_, _): isAnd;
                    case And(_, _): !isAnd;
                    case _: false;
                }
                if (needsParens) {
                    buf.add('(' + toString(node) + ')');
                }
                else {
                    buf.add(toString(node));
                }
        }
    }

}

/**
 * Recursive descent parser of `KeyBindingContextPredicate` (Rust passes the
 * remaining `&str` around; here a position in the source).
 */
private class PredicateParser {

    final source:String;

    public var pos:Int = 0;

    public function new(source:String) {
        this.source = source;
    }

    static final OPERATORS:Array<String> = ['>', '&&', '||', '==', '!='];

    static final PRECEDENCES:Array<Int> = [1, 3, 2, 4, 4]; // child, and, or, eq, neq

    function startsWith(op:String):Bool {
        if (pos + op.length > source.length) return false;
        for (i in 0...op.length) {
            if (StringTools.fastCodeAt(source, pos + i) != StringTools.fastCodeAt(op, i)) return false;
        }
        return true;
    }

    public function parseExpr(minPrecedence:Int):KeyBindingContextPredicate {
        var predicate = parsePrimary();

        while (true) {
            var matched = false;
            for (i in 0...OPERATORS.length) {
                final op = OPERATORS[i];
                final precedence = PRECEDENCES[i];
                if (startsWith(op) && precedence >= minPrecedence) {
                    pos = ContextScanner.skipWhitespace(source, pos + op.length);
                    final right = parseExpr(precedence + 1);
                    predicate = switch op {
                        case '>': Descendant(predicate, right);
                        case '&&': And(predicate, right);
                        case '||': Or(predicate, right);
                        case '==': newEq(predicate, right);
                        case _: newNeq(predicate, right);
                    }
                    matched = true;
                    break;
                }
            }
            if (!matched) break;
        }

        return predicate;
    }

    function parsePrimary():KeyBindingContextPredicate {
        if (pos >= source.length) {
            throw new haxe.Exception('unexpected end');
        }
        final next = StringTools.fastCodeAt(source, pos);
        if (next == '('.code) {
            pos = ContextScanner.skipWhitespace(source, pos + 1);
            final predicate = parseExpr(0);
            if (pos >= source.length || StringTools.fastCodeAt(source, pos) != ')'.code) {
                throw new haxe.Exception("expected a ')'");
            }
            pos = ContextScanner.skipWhitespace(source, pos + 1);
            return predicate;
        }
        else if (next == '!'.code) {
            pos = ContextScanner.skipWhitespace(source, pos + 1);
            final predicate = parseExpr(5); // PRECEDENCE_NOT
            return Not(predicate);
        }
        else if (ContextScanner.isIdentifierChar(next)) {
            final start = pos;
            while (pos < source.length) {
                final c = StringTools.fastCodeAt(source, pos);
                if (!ContextScanner.isIdentifierChar(c) && !ContextScanner.isVimOperatorChar(c)) break;
                pos++;
            }
            final identifier = source.substring(start, pos);
            pos = ContextScanner.skipWhitespace(source, pos);
            return Identifier(identifier);
        }
        else if (ContextScanner.isVimOperatorChar(next)) {
            final op = source.charAt(pos);
            pos = ContextScanner.skipWhitespace(source, pos + 1);
            return Identifier(op);
        }
        else {
            throw new haxe.Exception("unexpected character '" + debugChar(source, pos) + "'");
        }
    }

    static function newEq(left:KeyBindingContextPredicate, right:KeyBindingContextPredicate):KeyBindingContextPredicate {
        return switch [left, right] {
            case [Identifier(l), Identifier(r)]: Equal(l, r);
            case _: throw new haxe.Exception('operands of == must be identifiers');
        }
    }

    static function newNeq(left:KeyBindingContextPredicate, right:KeyBindingContextPredicate):KeyBindingContextPredicate {
        return switch [left, right] {
            case [Identifier(l), Identifier(r)]: NotEqual(l, r);
            case _: throw new haxe.Exception('operands of != must be identifiers');
        }
    }

    /**
     * Rust `{:?}` of a `char`: the character in single quotes, with escapes.
     */
    public static function debugChar(source:String, pos:Int):String {
        final c = source.charAt(pos);
        final escaped = switch c {
            case '\n': '\\n';
            case '\r': '\\r';
            case '\t': '\\t';
            case '\\': '\\\\';
            case "'": "\\'";
            case _: c;
        }
        return "'" + escaped + "'";
    }

}
