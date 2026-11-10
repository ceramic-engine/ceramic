// Ported from vscode src/vs/editor/contrib/symbolIcons/browser/symbolIcons.ts
// (and the color rules of symbolIcons.css)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.symbolIcons.view;

import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;

/**
 * The colors of the symbol icons (the outline, the breadcrumbs and the
 * suggest widget), `symbolIcon.*Foreground`, and the color of each symbol
 * codicon (symbolIcons.css).
 */
class SymbolIconColors {

    public static inline final arrayForeground:ColorIdentifier = 'symbolIcon.arrayForeground';
    public static inline final booleanForeground:ColorIdentifier = 'symbolIcon.booleanForeground';
    public static inline final classForeground:ColorIdentifier = 'symbolIcon.classForeground';
    public static inline final colorForeground:ColorIdentifier = 'symbolIcon.colorForeground';
    public static inline final constantForeground:ColorIdentifier = 'symbolIcon.constantForeground';
    public static inline final constructorForeground:ColorIdentifier = 'symbolIcon.constructorForeground';
    public static inline final enumeratorForeground:ColorIdentifier = 'symbolIcon.enumeratorForeground';
    public static inline final enumeratorMemberForeground:ColorIdentifier = 'symbolIcon.enumeratorMemberForeground';
    public static inline final eventForeground:ColorIdentifier = 'symbolIcon.eventForeground';
    public static inline final fieldForeground:ColorIdentifier = 'symbolIcon.fieldForeground';
    public static inline final fileForeground:ColorIdentifier = 'symbolIcon.fileForeground';
    public static inline final folderForeground:ColorIdentifier = 'symbolIcon.folderForeground';
    public static inline final functionForeground:ColorIdentifier = 'symbolIcon.functionForeground';
    public static inline final interfaceForeground:ColorIdentifier = 'symbolIcon.interfaceForeground';
    public static inline final keyForeground:ColorIdentifier = 'symbolIcon.keyForeground';
    public static inline final keywordForeground:ColorIdentifier = 'symbolIcon.keywordForeground';
    public static inline final methodForeground:ColorIdentifier = 'symbolIcon.methodForeground';
    public static inline final moduleForeground:ColorIdentifier = 'symbolIcon.moduleForeground';
    public static inline final namespaceForeground:ColorIdentifier = 'symbolIcon.namespaceForeground';
    public static inline final nullForeground:ColorIdentifier = 'symbolIcon.nullForeground';
    public static inline final numberForeground:ColorIdentifier = 'symbolIcon.numberForeground';
    public static inline final objectForeground:ColorIdentifier = 'symbolIcon.objectForeground';
    public static inline final operatorForeground:ColorIdentifier = 'symbolIcon.operatorForeground';
    public static inline final packageForeground:ColorIdentifier = 'symbolIcon.packageForeground';
    public static inline final propertyForeground:ColorIdentifier = 'symbolIcon.propertyForeground';
    public static inline final referenceForeground:ColorIdentifier = 'symbolIcon.referenceForeground';
    public static inline final snippetForeground:ColorIdentifier = 'symbolIcon.snippetForeground';
    public static inline final stringForeground:ColorIdentifier = 'symbolIcon.stringForeground';
    public static inline final structForeground:ColorIdentifier = 'symbolIcon.structForeground';
    public static inline final textForeground:ColorIdentifier = 'symbolIcon.textForeground';
    public static inline final typeParameterForeground:ColorIdentifier = 'symbolIcon.typeParameterForeground';
    public static inline final unitForeground:ColorIdentifier = 'symbolIcon.unitForeground';
    public static inline final variableForeground:ColorIdentifier = 'symbolIcon.variableForeground';

    /**
     * Registered with the other colors (`ColorRegistry.registerAllColors`).
     */
    public static function registerColors():Void {
        ColorUtils.registerColor(arrayForeground, BaseColors.foreground,
            'The foreground color for array symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(booleanForeground, BaseColors.foreground,
            'The foreground color for boolean symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(classForeground, {dark: '#EE9D28', light: '#D67E00', hcDark: '#EE9D28', hcLight: '#D67E00'},
            'The foreground color for class symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(colorForeground, BaseColors.foreground,
            'The foreground color for color symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(constantForeground, BaseColors.foreground,
            'The foreground color for constant symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(constructorForeground, {dark: '#B180D7', light: '#652D90', hcDark: '#B180D7', hcLight: '#652D90'},
            'The foreground color for constructor symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(enumeratorForeground, {dark: '#EE9D28', light: '#D67E00', hcDark: '#EE9D28', hcLight: '#D67E00'},
            'The foreground color for enumerator symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(enumeratorMemberForeground, {dark: '#75BEFF', light: '#007ACC', hcDark: '#75BEFF', hcLight: '#007ACC'},
            'The foreground color for enumerator member symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(eventForeground, {dark: '#EE9D28', light: '#D67E00', hcDark: '#EE9D28', hcLight: '#D67E00'},
            'The foreground color for event symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(fieldForeground, {dark: '#75BEFF', light: '#007ACC', hcDark: '#75BEFF', hcLight: '#007ACC'},
            'The foreground color for field symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(fileForeground, BaseColors.foreground,
            'The foreground color for file symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(folderForeground, BaseColors.foreground,
            'The foreground color for folder symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(functionForeground, {dark: '#B180D7', light: '#652D90', hcDark: '#B180D7', hcLight: '#652D90'},
            'The foreground color for function symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(interfaceForeground, {dark: '#75BEFF', light: '#007ACC', hcDark: '#75BEFF', hcLight: '#007ACC'},
            'The foreground color for interface symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(keyForeground, BaseColors.foreground,
            'The foreground color for key symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(keywordForeground, BaseColors.foreground,
            'The foreground color for keyword symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(methodForeground, {dark: '#B180D7', light: '#652D90', hcDark: '#B180D7', hcLight: '#652D90'},
            'The foreground color for method symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(moduleForeground, BaseColors.foreground,
            'The foreground color for module symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(namespaceForeground, BaseColors.foreground,
            'The foreground color for namespace symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(nullForeground, BaseColors.foreground,
            'The foreground color for null symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(numberForeground, BaseColors.foreground,
            'The foreground color for number symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(objectForeground, BaseColors.foreground,
            'The foreground color for object symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(operatorForeground, BaseColors.foreground,
            'The foreground color for operator symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(packageForeground, BaseColors.foreground,
            'The foreground color for package symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(propertyForeground, BaseColors.foreground,
            'The foreground color for property symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(referenceForeground, BaseColors.foreground,
            'The foreground color for reference symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(snippetForeground, BaseColors.foreground,
            'The foreground color for snippet symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(stringForeground, BaseColors.foreground,
            'The foreground color for string symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(structForeground, BaseColors.foreground,
            'The foreground color for struct symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(textForeground, BaseColors.foreground,
            'The foreground color for text symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(typeParameterForeground, BaseColors.foreground,
            'The foreground color for type parameter symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(unitForeground, BaseColors.foreground,
            'The foreground color for unit symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
        ColorUtils.registerColor(variableForeground, {dark: '#75BEFF', light: '#007ACC', hcDark: '#75BEFF', hcLight: '#007ACC'},
            'The foreground color for variable symbols. These symbols appear in the outline, breadcrumb, and suggest widget.');
    }

    /**
     * The color of a symbol codicon (symbolIcons.css: `.codicon-symbol-*`),
     * null for the other codicons.
     */
    public static function colorOf(codicon:String):Null<ColorIdentifier> {
        return switch codicon {
            case 'symbol-array': 'symbolIcon.arrayForeground';
            case 'symbol-boolean': 'symbolIcon.booleanForeground';
            case 'symbol-class': 'symbolIcon.classForeground';
            case 'symbol-method': 'symbolIcon.methodForeground';
            case 'symbol-color': 'symbolIcon.colorForeground';
            case 'symbol-constant': 'symbolIcon.constantForeground';
            case 'symbol-constructor': 'symbolIcon.constructorForeground';
            case 'symbol-value': 'symbolIcon.enumeratorForeground';
            case 'symbol-enum': 'symbolIcon.enumeratorForeground';
            case 'symbol-enum-member': 'symbolIcon.enumeratorMemberForeground';
            case 'symbol-event': 'symbolIcon.eventForeground';
            case 'symbol-field': 'symbolIcon.fieldForeground';
            case 'symbol-file': 'symbolIcon.fileForeground';
            case 'symbol-folder': 'symbolIcon.folderForeground';
            case 'symbol-function': 'symbolIcon.functionForeground';
            case 'symbol-interface': 'symbolIcon.interfaceForeground';
            case 'symbol-key': 'symbolIcon.keyForeground';
            case 'symbol-keyword': 'symbolIcon.keywordForeground';
            case 'symbol-module': 'symbolIcon.moduleForeground';
            case 'symbol-namespace': 'symbolIcon.namespaceForeground';
            case 'symbol-null': 'symbolIcon.nullForeground';
            case 'symbol-number': 'symbolIcon.numberForeground';
            case 'symbol-object': 'symbolIcon.objectForeground';
            case 'symbol-operator': 'symbolIcon.operatorForeground';
            case 'symbol-package': 'symbolIcon.packageForeground';
            case 'symbol-property': 'symbolIcon.propertyForeground';
            case 'symbol-reference': 'symbolIcon.referenceForeground';
            case 'symbol-snippet': 'symbolIcon.snippetForeground';
            case 'symbol-string': 'symbolIcon.stringForeground';
            case 'symbol-struct': 'symbolIcon.structForeground';
            case 'symbol-text': 'symbolIcon.textForeground';
            case 'symbol-type-parameter': 'symbolIcon.typeParameterForeground';
            case 'symbol-unit': 'symbolIcon.unitForeground';
            case 'symbol-variable': 'symbolIcon.variableForeground';
            case _: null;
        }
    }

}
