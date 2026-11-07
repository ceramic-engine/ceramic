// Ported from rust-i18n-support 4.2.1: src/lib.rs (parse_file, parse_file_v2, format_keys)
// Original code Copyright (c) 2021 Longbridge, licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic, with a reader for the
// subset of YAML the locale files use (gpui-kit's rust-i18n locale files). See NOTICE.md.
package glaze.kit;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Embeds the translations of `locales/*.yml` (next to this file) at compile
 * time, like rust-i18n's `i18n!("locales")` macro, as a JSON string
 * `{ locale: { key: text } }`.
 *
 * Only the version 2 layout of rust-i18n is supported (`_version: 2`, keys
 * nested in maps whose leaves map a locale to its text), written with block
 * maps and plain, single quoted or double quoted scalars.
 */
class I18nMacro {

    public static macro function translationsJson():Expr {

        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.join([haxe.io.Path.directory(sys.FileSystem.absolutePath(file)), 'locales']);
        final names = sys.FileSystem.readDirectory(dir);
        names.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        final translations:Dynamic = {};
        for (name in names) {
            if (!StringTools.endsWith(name, '.yml') && !StringTools.endsWith(name, '.yaml')) continue;
            final path = haxe.io.Path.join([dir, name]);
            Context.registerModuleDependency('glaze.kit.I18nMacro', path);
            final data:Dynamic = parseYaml(sys.io.File.getContent(path), path);
            final version:Dynamic = Reflect.field(data, '_version');
            if (version != 2) {
                Context.error('$path: only the rust-i18n version 2 layout (`_version: 2`) is supported', Context.currentPos());
            }
            final trs = parseFileV2('', data);
            if (trs == null) {
                Context.error('$path: invalid locale file format, please check the version field', Context.currentPos());
            }
            for (locale in Reflect.fields(trs)) {
                var table:Dynamic = Reflect.field(translations, locale);
                if (table == null) {
                    table = {};
                    Reflect.setField(translations, locale, table);
                }
                final sub:Dynamic = Reflect.field(trs, locale);
                for (key in Reflect.fields(sub)) {
                    Reflect.setField(table, key, Reflect.field(sub, key));
                }
            }
        }
        return macro $v{haxe.Json.stringify(translations)};

    }

    #if macro

    static function isObject(value:Dynamic):Bool {

        return value != null && Type.typeof(value) == TObject;

    }

    static function formatKeys(keys:Array<String>):String {

        return [for (key in keys) if (key.length > 0) key].join('.');

    }

    /**
     * Rust: `parse_file_v2`. Returns `{ locale: { key: text } }`, or `null`
     * when nothing was found.
     */
    static function parseFileV2(keyPrefix:String, data:Dynamic):Null<Dynamic> {

        final trs:Dynamic = {};
        var empty = true;

        if (isObject(data)) {
            for (key in Reflect.fields(data)) {
                final value:Dynamic = Reflect.field(data, key);
                if (!isObject(value)) continue;
                for (locale in Reflect.fields(value)) {
                    final text:Dynamic = Reflect.field(value, locale);
                    if (Std.isOfType(text, String)) {
                        final fullKey = formatKeys([keyPrefix, key]);
                        var table:Dynamic = Reflect.field(trs, locale);
                        if (table == null) {
                            table = {};
                            Reflect.setField(trs, locale, table);
                        }
                        Reflect.setField(table, fullKey, text);
                        empty = false;
                        continue;
                    }

                    if (isObject(text)) {
                        final fullKey = formatKeys([keyPrefix, key]);
                        final subTrs = parseFileV2(fullKey, value);
                        if (subTrs != null) {
                            for (subLocale in Reflect.fields(subTrs)) {
                                var table:Dynamic = Reflect.field(trs, subLocale);
                                if (table == null) {
                                    table = {};
                                    Reflect.setField(trs, subLocale, table);
                                }
                                final sub:Dynamic = Reflect.field(subTrs, subLocale);
                                for (k in Reflect.fields(sub)) {
                                    Reflect.setField(table, k, Reflect.field(sub, k));
                                }
                                empty = false;
                            }
                        }
                    }
                }
            }
        }

        return empty ? null : trs;

    }

    /**
     * Reads block maps of scalars (the YAML used by locale files). Plain
     * scalars that YAML 1.2 resolves to null, booleans or numbers are not
     * strings, so rust-i18n skips them: they are kept as such here.
     */
    static function parseYaml(content:String, path:String):Dynamic {

        final root:Dynamic = {};
        // Stack of (indent, map)
        final indents:Array<Int> = [-1];
        final maps:Array<Dynamic> = [root];
        var lineNumber = 0;

        for (rawLine in ~/\r?\n/g.split(content)) {
            lineNumber++;
            final trimmed = StringTools.trim(rawLine);
            if (trimmed.length == 0 || StringTools.startsWith(trimmed, '#') || trimmed == '---') continue;

            var indent = 0;
            while (indent < rawLine.length && rawLine.charCodeAt(indent) == ' '.code) indent++;
            if (indent < rawLine.length && rawLine.charCodeAt(indent) == '\t'.code) {
                Context.error('$path:$lineNumber: tabs are not allowed for indentation', Context.currentPos());
            }

            while (indent <= indents[indents.length - 1]) {
                indents.pop();
                maps.pop();
            }

            final line = rawLine.substr(indent);
            var key:String;
            var rest:String;
            if (line.charCodeAt(0) == '"'.code || line.charCodeAt(0) == "'".code) {
                final parsed = readQuoted(line, 0, path, lineNumber);
                key = parsed.value;
                rest = line.substr(parsed.end);
                if (!StringTools.startsWith(rest, ':')) {
                    Context.error('$path:$lineNumber: expected `:` after the key', Context.currentPos());
                }
                rest = rest.substr(1);
            }
            else {
                var colon = -1;
                for (i in 0...line.length) {
                    if (line.charCodeAt(i) == ':'.code && (i + 1 == line.length || line.charCodeAt(i + 1) == ' '.code)) {
                        colon = i;
                        break;
                    }
                }
                if (colon < 0) {
                    Context.error('$path:$lineNumber: unsupported YAML (expected `key: value`)', Context.currentPos());
                }
                key = StringTools.trim(line.substr(0, colon));
                rest = line.substr(colon + 1);
            }

            final valueText = StringTools.trim(rest);
            final parent = maps[maps.length - 1];
            if (valueText.length == 0 || StringTools.startsWith(valueText, '#')) {
                final map:Dynamic = {};
                Reflect.setField(parent, key, map);
                indents.push(indent);
                maps.push(map);
            }
            else {
                Reflect.setField(parent, key, readScalar(valueText, path, lineNumber));
            }
        }

        return root;

    }

    static function readQuoted(text:String, start:Int, path:String, lineNumber:Int):{value:String, end:Int} {

        final quote = text.charCodeAt(start);
        final buf = new StringBuf();
        var i = start + 1;
        while (i < text.length) {
            final c = text.charCodeAt(i);
            if (quote == "'".code) {
                if (c == "'".code) {
                    if (i + 1 < text.length && text.charCodeAt(i + 1) == "'".code) {
                        buf.addChar("'".code);
                        i += 2;
                        continue;
                    }
                    return {value: buf.toString(), end: i + 1};
                }
                buf.addChar(c);
                i++;
            }
            else {
                if (c == '"'.code) {
                    return {value: buf.toString(), end: i + 1};
                }
                if (c == '\\'.code && i + 1 < text.length) {
                    final e = text.charCodeAt(i + 1);
                    switch e {
                        case 'n'.code: buf.addChar('\n'.code);
                        case 't'.code: buf.addChar('\t'.code);
                        case 'r'.code: buf.addChar('\r'.code);
                        case '0'.code: buf.addChar(0);
                        case '"'.code: buf.addChar('"'.code);
                        case '\\'.code: buf.addChar('\\'.code);
                        case '/'.code: buf.addChar('/'.code);
                        case ' '.code: buf.addChar(' '.code);
                        case 'u'.code:
                            buf.addChar(Std.parseInt('0x' + text.substr(i + 2, 4)));
                            i += 4;
                        case _:
                            Context.error('$path:$lineNumber: unsupported escape sequence', Context.currentPos());
                    }
                    i += 2;
                    continue;
                }
                buf.addChar(c);
                i++;
            }
        }
        Context.error('$path:$lineNumber: unterminated quoted scalar', Context.currentPos());
        return null;

    }

    static function readScalar(text:String, path:String, lineNumber:Int):Dynamic {

        final first = text.charCodeAt(0);
        if (first == '"'.code || first == "'".code) {
            final parsed = readQuoted(text, 0, path, lineNumber);
            final after = StringTools.trim(text.substr(parsed.end));
            if (after.length > 0 && !StringTools.startsWith(after, '#')) {
                Context.error('$path:$lineNumber: unexpected text after a quoted scalar', Context.currentPos());
            }
            return parsed.value;
        }
        if (first == '|'.code || first == '>'.code || first == '['.code || first == '{'.code
            || first == '&'.code || first == '*'.code || first == '!'.code) {
            Context.error('$path:$lineNumber: unsupported YAML (block scalars, flow collections, anchors and tags)', Context.currentPos());
        }

        // Plain scalar: a comment starts at ` #`
        var value = text;
        final comment = value.indexOf(' #');
        if (comment >= 0) value = StringTools.trim(value.substr(0, comment));

        // YAML 1.2 core schema: these are not strings
        if (value == '~' || value == 'null' || value == 'Null' || value == 'NULL') return null;
        if (value == 'true' || value == 'True' || value == 'TRUE') return true;
        if (value == 'false' || value == 'False' || value == 'FALSE') return false;
        if (~/^[-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?$/.match(value)) return Std.parseFloat(value);
        return value;

    }

    #end

}
