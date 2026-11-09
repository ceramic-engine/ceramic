// New code for Cityscape (not a port): tests of VSCodeTheme (VS Code theme reader).
package tests.standalone;

import cityscape.standalone.common.VSCodeTheme;
import testing.TestCase;

/**
 * VSCodeTheme on a One Dark style tmTheme (copied below as JSON: the default
 * theme of loreline-monaco, src/theme-dark.js, generic TextMate scopes only);
 * the expected colors are the values written in that theme, under the color
 * ids loreline-monaco's `extractThemeColors` gives them.
 */
class VSCodeThemeTest extends TestCase {

    static final THEME_DARK_JSON = '
        {
            "name": "One Dark (jeremyfa)",
            "colors": {},
            "settings": [
                {
                    "settings": {
                        "foreground": "#dddddd",
                        "background": "#202020",
                        "caret": "#528bff",
                        "invisibles": "#4b525b",
                        "lineHighlight": "#282828",
                        "selection": "#424242"
                    }
                },
                {
                    "name": "Indent guides",
                    "scope": "editorIndentGuide.background",
                    "settings": {
                        "foreground": "#FF00FF"
                    }
                },
                {
                    "name": "Active indent guides",
                    "scope": "editorIndentGuide.activeBackground",
                    "settings": {
                        "foreground": "#FF00FF"
                    }
                },
                {
                    "name": "Comments",
                    "scope": [
                        "comment",
                        "punctuation.definition.comment"
                    ],
                    "settings": {
                        "foreground": "#5c6370",
                        "fontStyle": "italic"
                    }
                },
                {
                    "name": "Delimiters",
                    "scope": [
                        "none"
                    ],
                    "settings": {
                        "foreground": "#a6b2c0"
                    }
                },
                {
                    "name": "Operators",
                    "scope": [
                        "keyword.operator"
                    ],
                    "settings": {
                        "foreground": "#dddddd"
                    }
                },
                {
                    "name": "Keywords",
                    "scope": [
                        "keyword"
                    ],
                    "settings": {
                        "foreground": "#c678dd"
                    }
                },
                {
                    "name": "Variables",
                    "scope": [
                        "variable"
                    ],
                    "settings": {
                        "foreground": "#e06c75"
                    }
                },
                {
                    "name": "Functions",
                    "scope": [
                        "entity.name.function",
                        "meta.require",
                        "support.function.any-method",
                        "entity.name.class"
                    ],
                    "settings": {
                        "foreground": "#61afef"
                    }
                },
                {
                    "name": "Classes",
                    "scope": [
                        "entity.name.type.namespace",
                        "support.class",
                        "entity.name.type.class",
                        "entity.name.type"
                    ],
                    "settings": {
                        "foreground": "#e5c07b"
                    }
                },
                {
                    "name": "Methods",
                    "scope": [
                        "keyword.other.special-method"
                    ],
                    "settings": {
                        "foreground": "#61afef"
                    }
                },
                {
                    "name": "Storage",
                    "scope": [
                        "storage"
                    ],
                    "settings": {
                        "foreground": "#c678dd"
                    }
                },
                {
                    "name": "Support Type Property Names",
                    "scope": [
                        "support.type.property-name"
                    ],
                    "settings": {
                        "foreground": "#dddddd"
                    }
                },
                {
                    "name": "Constants",
                    "scope": [
                        "constant"
                    ],
                    "settings": {
                        "foreground": "#d19a66"
                    }
                },
                {
                    "name": "Strings",
                    "scope": [
                        "string",
                        "entity.other.inherited-class"
                    ],
                    "settings": {
                        "foreground": "#98c379"
                    }
                },
                {
                    "name": "Regular Expressions",
                    "scope": [
                        "string.regexp"
                    ],
                    "settings": {
                        "foreground": "#56b6c2"
                    }
                },
                {
                    "name": "Escape Characters",
                    "scope": [
                        "constant.character.escape"
                    ],
                    "settings": {
                        "foreground": "#57b6c2"
                    }
                },
                {
                    "name": "Embedded",
                    "scope": [
                        "punctuation.section.embedded",
                        "variable.interpolation"
                    ],
                    "settings": {
                        "foreground": "#be4f44"
                    }
                },
                {
                    "name": "Invalid",
                    "scope": [
                        "invalid.illegal"
                    ],
                    "settings": {
                        "background": "#e05252",
                        "foreground": "#ffffff"
                    }
                },
                {
                    "name": "Broken",
                    "scope": [
                        "invalid.broken"
                    ],
                    "settings": {
                        "background": "#e05252",
                        "foreground": "#ffffff"
                    }
                },
                {
                    "name": "Deprecated",
                    "scope": [
                        "invalid.deprecated"
                    ],
                    "settings": {
                        "background": "#d27b53",
                        "foreground": "#ffffff"
                    }
                },
                {
                    "name": "HTML/XML Tags",
                    "scope": [
                        "entity.name.tag"
                    ],
                    "settings": {
                        "foreground": "#e06c75"
                    }
                },
                {
                    "name": "Markup Bold",
                    "scope": [
                        "markup.bold",
                        "punctuation.definition.bold"
                    ],
                    "settings": {
                        "foreground": "#d19a66"
                    }
                },
                {
                    "name": "Markup Italic",
                    "scope": [
                        "markup.italic",
                        "punctuation.definition.italic"
                    ],
                    "settings": {
                        "foreground": "#c678dd"
                    }
                },
                {
                    "name": "Markup Headings",
                    "scope": [
                        "markup.heading"
                    ],
                    "settings": {
                        "foreground": "#e06c75"
                    }
                },
                {
                    "name": "Markup Links",
                    "scope": [
                        "meta.link"
                    ],
                    "settings": {
                        "foreground": "#c678dd"
                    }
                },
                {
                    "name": "Markup Lists",
                    "scope": [
                        "markup.list.punctuation.definition"
                    ],
                    "settings": {
                        "foreground": "#df6a73"
                    }
                },
                {
                    "name": "Markup Quotes",
                    "scope": [
                        "markup.quote"
                    ],
                    "settings": {
                        "foreground": "#d2945d"
                    }
                },
                {
                    "name": "Markup Separator",
                    "scope": [
                        "meta.separator"
                    ],
                    "settings": {
                        "background": "#515151",
                        "foreground": "#a6b2c0"
                    }
                },
                {
                    "name": "Metadata",
                    "scope": [
                        "storage.modifier.metadata"
                    ],
                    "settings": {
                        "foreground": "#59bec3"
                    }
                },
                {
                    "name": "DOM",
                    "scope": [
                        "support.variable.dom"
                    ],
                    "settings": {
                        "foreground": "#e5c07b"
                    }
                },
                {
                    "name": "Template Expressions",
                    "scope": [
                        "punctuation.definition.template-expression.begin",
                        "punctuation.definition.template-expression.end"
                    ],
                    "settings": {
                        "foreground": "#be5046"
                    }
                },
                {
                    "name": "Meta Tag",
                    "scope": [
                        "meta.tag"
                    ],
                    "settings": {
                        "foreground": "#dddddd"
                    }
                },
                {
                    "name": "Preprocessor Directives",
                    "scope": [
                        "punctuation.definition.tag"
                    ],
                    "settings": {
                        "foreground": "#8ca0b9"
                    }
                }
            ]
        }
    ';

    function testOneDarkTheme() {
        final theme:Dynamic = haxe.Json.parse(THEME_DARK_JSON);
        final data = VSCodeTheme.toStandaloneThemeData(theme);

        assertEquals('vs-dark', data.base);
        assertEquals(true, data.inherit);
        assertEquals(0, data.rules.length);

        final keys = [for (k in data.colors.keys()) k];
        keys.sort(Reflect.compare);
        assertEquals('editor.background,editor.foreground,editor.lineHighlightBackground,editor.selectionBackground,editorCursor.foreground,editorWhitespace.foreground', keys.join(','));
        assertEquals('#dddddd', data.colors.get('editor.foreground'));
        assertEquals('#202020', data.colors.get('editor.background'));
        assertEquals('#528bff', data.colors.get('editorCursor.foreground'));
        assertEquals('#4b525b', data.colors.get('editorWhitespace.foreground'));
        assertEquals('#282828', data.colors.get('editor.lineHighlightBackground'));
        assertEquals('#424242', data.colors.get('editor.selectionBackground'));

        // The settings are carried as they are
        final settings:Array<Dynamic> = theme.settings;
        assertTrue(data.tokenColors == settings);
        assertEquals(34, data.tokenColors.length);
        assertEquals('Comments', data.tokenColors[3].name);
    }

    function testColorsOverrideGlobalSettings() {
        final data = VSCodeTheme.toStandaloneThemeData({
            type: 'light',
            colors: {
                'editor.background': '#ffffff',
                'editorLineNumber.foreground': '#999999'
            },
            tokenColors: ([
                {settings: {background: '#fafafa', foreground: '#333333', findMatchHighlight: '#ffff00', guide: '#eeeeee', activeGuide: '#cccccc'}},
                {scope: 'comment', settings: {foreground: '#008000', background: '#000000'}}
            ] : Array<Dynamic>)
        });
        assertEquals('vs', data.base);
        assertEquals('#ffffff', data.colors.get('editor.background'));
        assertEquals('#333333', data.colors.get('editor.foreground'));
        assertEquals('#999999', data.colors.get('editorLineNumber.foreground'));
        assertEquals('#ffff00', data.colors.get('editor.findMatchHighlightBackground'));
        assertEquals('#eeeeee', data.colors.get('editorIndentGuide.background'));
        assertEquals('#cccccc', data.colors.get('editorIndentGuide.activeBackground'));
        assertEquals(2, data.tokenColors.length);
    }

    function testBaseFromType() {
        assertEquals('vs-dark', VSCodeTheme.toStandaloneThemeData({}).base);
        assertEquals('vs-dark', VSCodeTheme.toStandaloneThemeData({type: 'dark'}).base);
        assertEquals('vs-dark', VSCodeTheme.toStandaloneThemeData({type: 'vs-dark'}).base);
        assertEquals('vs-dark', VSCodeTheme.toStandaloneThemeData({type: 'unknown'}).base);
        assertEquals('vs', VSCodeTheme.toStandaloneThemeData({type: 'light'}).base);
        assertEquals('vs', VSCodeTheme.toStandaloneThemeData({type: 'vs'}).base);
        assertEquals('hc-black', VSCodeTheme.toStandaloneThemeData({type: 'hc'}).base);
        assertEquals('hc-black', VSCodeTheme.toStandaloneThemeData({type: 'hcDark'}).base);
        assertEquals('hc-black', VSCodeTheme.toStandaloneThemeData({type: 'hc-black'}).base);
        assertEquals('hc-light', VSCodeTheme.toStandaloneThemeData({type: 'hcLight'}).base);
        assertEquals('hc-light', VSCodeTheme.toStandaloneThemeData({type: 'hc-light'}).base);
        assertNull(VSCodeTheme.toStandaloneThemeData({type: 'light'}).tokenColors);
    }

}
