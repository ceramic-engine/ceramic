// Ported from vscode src/vs/editor/standalone/common/themes.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.standalone.common;

import cityscape.common.core.EditorColorRegistry;
import cityscape.platform.theme.common.colors.EditorColors;
import cityscape.standalone.common.StandaloneTheme.IColors;
import cityscape.standalone.common.StandaloneTheme.IStandaloneThemeData;

/**
 * The data of the built-in themes `vs`, `vs-dark`, `hc-black` and
 * `hc-light`, built on first use. Shared by all contexts: never modify it.
 */
class Themes {

    public static var vs(get, null):IStandaloneThemeData;

    static function get_vs():IStandaloneThemeData {
        if (vs == null) {
            vs = create_vs();
        }
        return vs;
    }

    public static var vs_dark(get, null):IStandaloneThemeData;

    static function get_vs_dark():IStandaloneThemeData {
        if (vs_dark == null) {
            vs_dark = create_vs_dark();
        }
        return vs_dark;
    }

    public static var hc_black(get, null):IStandaloneThemeData;

    static function get_hc_black():IStandaloneThemeData {
        if (hc_black == null) {
            hc_black = create_hc_black();
        }
        return hc_black;
    }

    public static var hc_light(get, null):IStandaloneThemeData;

    static function get_hc_light():IStandaloneThemeData {
        if (hc_light == null) {
            hc_light = create_hc_light();
        }
        return hc_light;
    }

    // Begin vs theme
    static function create_vs():IStandaloneThemeData {
        return {
            base: 'vs',
            inherit: false,
            rules: [
                { token: '', foreground: '000000', background: 'fffffe' },
                { token: 'invalid', foreground: 'cd3131' },
                { token: 'emphasis', fontStyle: 'italic' },
                { token: 'strong', fontStyle: 'bold' },

                { token: 'variable', foreground: '001188' },
                { token: 'variable.predefined', foreground: '4864AA' },
                { token: 'constant', foreground: 'dd0000' },
                { token: 'comment', foreground: '008000' },
                { token: 'number', foreground: '098658' },
                { token: 'number.hex', foreground: '3030c0' },
                { token: 'regexp', foreground: '800000' },
                { token: 'annotation', foreground: '808080' },
                { token: 'type', foreground: '008080' },

                { token: 'delimiter', foreground: '000000' },
                { token: 'delimiter.html', foreground: '383838' },
                { token: 'delimiter.xml', foreground: '0000FF' },

                { token: 'tag', foreground: '800000' },
                { token: 'tag.id.pug', foreground: '4F76AC' },
                { token: 'tag.class.pug', foreground: '4F76AC' },
                { token: 'meta.scss', foreground: '800000' },
                { token: 'metatag', foreground: 'e00000' },
                { token: 'metatag.content.html', foreground: 'FF0000' },
                { token: 'metatag.html', foreground: '808080' },
                { token: 'metatag.xml', foreground: '808080' },
                { token: 'metatag.php', fontStyle: 'bold' },

                { token: 'key', foreground: '863B00' },
                { token: 'string.key.json', foreground: 'A31515' },
                { token: 'string.value.json', foreground: '0451A5' },

                { token: 'attribute.name', foreground: 'FF0000' },
                { token: 'attribute.value', foreground: '0451A5' },
                { token: 'attribute.value.number', foreground: '098658' },
                { token: 'attribute.value.unit', foreground: '098658' },
                { token: 'attribute.value.html', foreground: '0000FF' },
                { token: 'attribute.value.xml', foreground: '0000FF' },

                { token: 'string', foreground: 'A31515' },
                { token: 'string.html', foreground: '0000FF' },
                { token: 'string.sql', foreground: 'FF0000' },
                { token: 'string.yaml', foreground: '0451A5' },

                { token: 'keyword', foreground: '0000FF' },
                { token: 'keyword.json', foreground: '0451A5' },
                { token: 'keyword.flow', foreground: 'AF00DB' },
                { token: 'keyword.flow.scss', foreground: '0000FF' },

                { token: 'operator.scss', foreground: '666666' },
                { token: 'operator.sql', foreground: '778899' },
                { token: 'operator.swift', foreground: '666666' },
                { token: 'predefined.sql', foreground: 'C700C7' },
            ],
            colors: colors([
                EditorColors.editorBackground => '#FFFFFE',
                EditorColors.editorForeground => '#000000',
                EditorColors.editorInactiveSelection => '#E5EBF1',
                EditorColorRegistry.editorIndentGuide1 => '#D3D3D3',
                EditorColorRegistry.editorActiveIndentGuide1 => '#939393',
                EditorColors.editorSelectionHighlight => '#ADD6FF4D'
            ])
        };
    }
    // End vs theme


    // Begin vs-dark theme
    static function create_vs_dark():IStandaloneThemeData {
        return {
            base: 'vs-dark',
            inherit: false,
            rules: [
                { token: '', foreground: 'D4D4D4', background: '1E1E1E' },
                { token: 'invalid', foreground: 'f44747' },
                { token: 'emphasis', fontStyle: 'italic' },
                { token: 'strong', fontStyle: 'bold' },

                { token: 'variable', foreground: '74B0DF' },
                { token: 'variable.predefined', foreground: '4864AA' },
                { token: 'variable.parameter', foreground: '9CDCFE' },
                { token: 'constant', foreground: '569CD6' },
                { token: 'comment', foreground: '608B4E' },
                { token: 'number', foreground: 'B5CEA8' },
                { token: 'number.hex', foreground: '5BB498' },
                { token: 'regexp', foreground: 'B46695' },
                { token: 'annotation', foreground: 'cc6666' },
                { token: 'type', foreground: '3DC9B0' },

                { token: 'delimiter', foreground: 'DCDCDC' },
                { token: 'delimiter.html', foreground: '808080' },
                { token: 'delimiter.xml', foreground: '808080' },

                { token: 'tag', foreground: '569CD6' },
                { token: 'tag.id.pug', foreground: '4F76AC' },
                { token: 'tag.class.pug', foreground: '4F76AC' },
                { token: 'meta.scss', foreground: 'A79873' },
                { token: 'meta.tag', foreground: 'CE9178' },
                { token: 'metatag', foreground: 'DD6A6F' },
                { token: 'metatag.content.html', foreground: '9CDCFE' },
                { token: 'metatag.html', foreground: '569CD6' },
                { token: 'metatag.xml', foreground: '569CD6' },
                { token: 'metatag.php', fontStyle: 'bold' },

                { token: 'key', foreground: '9CDCFE' },
                { token: 'string.key.json', foreground: '9CDCFE' },
                { token: 'string.value.json', foreground: 'CE9178' },

                { token: 'attribute.name', foreground: '9CDCFE' },
                { token: 'attribute.value', foreground: 'CE9178' },
                { token: 'attribute.value.number.css', foreground: 'B5CEA8' },
                { token: 'attribute.value.unit.css', foreground: 'B5CEA8' },
                { token: 'attribute.value.hex.css', foreground: 'D4D4D4' },

                { token: 'string', foreground: 'CE9178' },
                { token: 'string.sql', foreground: 'FF0000' },

                { token: 'keyword', foreground: '569CD6' },
                { token: 'keyword.flow', foreground: 'C586C0' },
                { token: 'keyword.json', foreground: 'CE9178' },
                { token: 'keyword.flow.scss', foreground: '569CD6' },

                { token: 'operator.scss', foreground: '909090' },
                { token: 'operator.sql', foreground: '778899' },
                { token: 'operator.swift', foreground: '909090' },
                { token: 'predefined.sql', foreground: 'FF00FF' },
            ],
            colors: colors([
                EditorColors.editorBackground => '#1E1E1E',
                EditorColors.editorForeground => '#D4D4D4',
                EditorColors.editorInactiveSelection => '#3A3D41',
                EditorColorRegistry.editorIndentGuide1 => '#404040',
                EditorColorRegistry.editorActiveIndentGuide1 => '#707070',
                EditorColors.editorSelectionHighlight => '#ADD6FF26'
            ])
        };
    }
    // End vs-dark theme



    // Begin hc-black theme
    static function create_hc_black():IStandaloneThemeData {
        return {
            base: 'hc-black',
            inherit: false,
            rules: [
                { token: '', foreground: 'FFFFFF', background: '000000' },
                { token: 'invalid', foreground: 'f44747' },
                { token: 'emphasis', fontStyle: 'italic' },
                { token: 'strong', fontStyle: 'bold' },

                { token: 'variable', foreground: '1AEBFF' },
                { token: 'variable.parameter', foreground: '9CDCFE' },
                { token: 'constant', foreground: '569CD6' },
                { token: 'comment', foreground: '608B4E' },
                { token: 'number', foreground: 'FFFFFF' },
                { token: 'regexp', foreground: 'C0C0C0' },
                { token: 'annotation', foreground: '569CD6' },
                { token: 'type', foreground: '3DC9B0' },

                { token: 'delimiter', foreground: 'FFFF00' },
                { token: 'delimiter.html', foreground: 'FFFF00' },

                { token: 'tag', foreground: '569CD6' },
                { token: 'tag.id.pug', foreground: '4F76AC' },
                { token: 'tag.class.pug', foreground: '4F76AC' },
                { token: 'meta', foreground: 'D4D4D4' },
                { token: 'meta.tag', foreground: 'CE9178' },
                { token: 'metatag', foreground: '569CD6' },
                { token: 'metatag.content.html', foreground: '1AEBFF' },
                { token: 'metatag.html', foreground: '569CD6' },
                { token: 'metatag.xml', foreground: '569CD6' },
                { token: 'metatag.php', fontStyle: 'bold' },

                { token: 'key', foreground: '9CDCFE' },
                { token: 'string.key', foreground: '9CDCFE' },
                { token: 'string.value', foreground: 'CE9178' },

                { token: 'attribute.name', foreground: '569CD6' },
                { token: 'attribute.value', foreground: '3FF23F' },

                { token: 'string', foreground: 'CE9178' },
                { token: 'string.sql', foreground: 'FF0000' },

                { token: 'keyword', foreground: '569CD6' },
                { token: 'keyword.flow', foreground: 'C586C0' },

                { token: 'operator.sql', foreground: '778899' },
                { token: 'operator.swift', foreground: '909090' },
                { token: 'predefined.sql', foreground: 'FF00FF' },
            ],
            colors: colors([
                EditorColors.editorBackground => '#000000',
                EditorColors.editorForeground => '#FFFFFF',
                EditorColorRegistry.editorIndentGuide1 => '#FFFFFF',
                EditorColorRegistry.editorActiveIndentGuide1 => '#FFFFFF',
            ])
        };
    }
    // End hc-black theme

    // Begin hc-light theme
    static function create_hc_light():IStandaloneThemeData {
        return {
            base: 'hc-light',
            inherit: false,
            rules: [
                { token: '', foreground: '292929', background: 'FFFFFF' },
                { token: 'invalid', foreground: 'B5200D' },
                { token: 'emphasis', fontStyle: 'italic' },
                { token: 'strong', fontStyle: 'bold' },

                { token: 'variable', foreground: '264F70' },
                { token: 'variable.predefined', foreground: '4864AA' },
                { token: 'constant', foreground: 'dd0000' },
                { token: 'comment', foreground: '008000' },
                { token: 'number', foreground: '098658' },
                { token: 'number.hex', foreground: '3030c0' },
                { token: 'regexp', foreground: '800000' },
                { token: 'annotation', foreground: '808080' },
                { token: 'type', foreground: '008080' },

                { token: 'delimiter', foreground: '000000' },
                { token: 'delimiter.html', foreground: '383838' },

                { token: 'tag', foreground: '800000' },
                { token: 'tag.id.pug', foreground: '4F76AC' },
                { token: 'tag.class.pug', foreground: '4F76AC' },
                { token: 'meta.scss', foreground: '800000' },
                { token: 'metatag', foreground: 'e00000' },
                { token: 'metatag.content.html', foreground: 'B5200D' },
                { token: 'metatag.html', foreground: '808080' },
                { token: 'metatag.xml', foreground: '808080' },
                { token: 'metatag.php', fontStyle: 'bold' },

                { token: 'key', foreground: '863B00' },
                { token: 'string.key.json', foreground: 'A31515' },
                { token: 'string.value.json', foreground: '0451A5' },

                { token: 'attribute.name', foreground: '264F78' },
                { token: 'attribute.value', foreground: '0451A5' },

                { token: 'string', foreground: 'A31515' },
                { token: 'string.sql', foreground: 'B5200D' },

                { token: 'keyword', foreground: '0000FF' },
                { token: 'keyword.flow', foreground: 'AF00DB' },

                { token: 'operator.sql', foreground: '778899' },
                { token: 'operator.swift', foreground: '666666' },
                { token: 'predefined.sql', foreground: 'C700C7' },
            ],
            colors: colors([
                EditorColors.editorBackground => '#FFFFFF',
                EditorColors.editorForeground => '#292929',
                EditorColorRegistry.editorIndentGuide1 => '#292929',
                EditorColorRegistry.editorActiveIndentGuide1 => '#292929',
            ])
        };
    }
    // End hc-light theme

    static function colors(map:Map<String, String>):IColors {
        final result = new haxe.DynamicAccess<String>();
        for (key => value in map) {
            result.set(key, value);
        }
        return result;
    }

}
