package ceramic.macros;

#if macro

import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.Expr;
import haxe.macro.TypeTools;
import haxe.macro.TypedExprTools;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import haxe.crypto.Md5;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/** Export Runtime Type Information into external XML files. */
class ExportApi {

    static var outputSubPath:String = 'api';

    public static function export(outputSubPath:String = 'api'):Void {

        ExportApi.outputSubPath = outputSubPath;

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN ExportApi.export()');
        #end

        var isCompletion = Context.defined('completion') || Context.defined('display');
        if (isCompletion) return;

        var exportPath = getExportPath();
        if (exportPath == null) {
            return;
        }

        var ceramicRootPath = Context.definedValue('ceramic_root_path');
        if (ceramicRootPath == null) {
            return;
        }
        var allApiPath = Path.join([ceramicRootPath, 'runtime', 'src', 'ceramic', 'AllApi.hx']);
        var allApiContent = File.getContent(allApiPath);

        var typesToExport:Map<String,String> = new Map();

        for (line in allApiContent.split('\n')) {
            line = line.trim();
            if (line.startsWith('import ') && RE_IMPORT.match(line)) {
                var typeStr = RE_IMPORT.matched(1);
                var nameAlias = RE_IMPORT.matched(2);
                var name = nameAlias != null && nameAlias != '' ? nameAlias : typeStr;
                var dotIndex = name.lastIndexOf('.');
                if (dotIndex != -1) {
                    name = name.substring(dotIndex + 1);
                }
                typesToExport.set(typeStr, name);
            }
        }

        /*
        Context.onGenerate(function(types) {

            for (type in types) {
                switch (type) {
                    case TInst(t, params):
                        if (t.get().meta.has('exportApi')) {
                            typesToExport.set(t.toString(), t.get().name);
                        }
                    default:
                }
            }

        });
        */

        Context.onAfterGenerate(function() {

            var dts = new StringBuf();
            var tab = '    ';

            dts.add('\n');
            dts.add('type Int = number;\n');
            dts.add('type Float = number;\n');
            dts.add('type Bool = boolean;\n');
            dts.add('type String = string;\n');
            dts.add('type Dynamic = any;\n');
            dts.add('type Void = void;\n');
            dts.add('type ReadOnlyArray = ReadonlyArray;\n');
            dts.add('\n');
            dts.add('function trace(msg: any): Void;\n');
            dts.add('\n');
            dts.add('function get(id: String): Entity;\n');
            dts.add('function module(id: String): ScriptModule;\n');
            dts.add('\n');
            dts.add('type AnyVisual = Visual & Text & Mesh & Quad;\n');
            dts.add('\n');
            dts.add('const self: Entity;\n');
            dts.add('const entity: Entity;\n');
            dts.add('const visual: AnyVisual;\n');
            dts.add('const fragment: Fragment;\n');
            dts.add('\n');
            dts.add('const app: App;\n');
            dts.add('const screen: Screen;\n');
            dts.add('const audio: Audio;\n');
            dts.add('const settings: Settings;\n');
            //dts.add('const collections: Collections;\n');
            dts.add('const log: Logger;\n');
            dts.add('\n');
            dts.add('interface Array<T> {\n');
            dts.add('    [index: number]: T;\n');
            dts.add('}\n');
            dts.add('\n');
            dts.add('var a: number;\n');
            dts.add('var b: number;\n');
            dts.add('var c: number;\n');
            dts.add('var d: number;\n');
            dts.add('var e: number;\n');
            dts.add('var f: number;\n');
            dts.add('var g: number;\n');
            dts.add('var h: number;\n');
            dts.add('var i: number;\n');
            dts.add('var j: number;\n');
            dts.add('var k: number;\n');
            dts.add('var l: number;\n');
            dts.add('var m: number;\n');
            dts.add('var n: number;\n');
            dts.add('var o: number;\n');
            dts.add('var p any;\n');
            dts.add('var q: number;\n');
            dts.add('var r: number;\n');
            dts.add('var s: number;\n');
            dts.add('var t: number;\n');
            dts.add('var u: number;\n');
            dts.add('var v: number;\n');
            dts.add('var w: number;\n');
            dts.add('var x: number;\n');
            dts.add('var y: number;\n');
            dts.add('var z: number;\n');
            dts.add('\n');
            
            for (typeName in typesToExport.keys()) {
                var type = Context.getType(typeName);
                if (type != null) {
                    switch type {
                        case TMono(t):
                        case TEnum(t, params):
                            var enumType = t.get();
                            if (enumType.doc != null && enumType.doc.trim() != '') {
                                dts.add(tab);
                                dts.add('/**');
                                dts.add(enumType.doc);
                                dts.add('*/\n');
                            }
                            dts.add('enum ');
                            dts.add(enumType.name);
                            if (enumType.params != null && enumType.params.length > 0) {
                                dts.add('<');
                                var paramI = 0;
                                for (param in enumType.params) {
                                    if (paramI++ > 0) {
                                        dts.add(', ');
                                    }
                                    dts.add(typeToString(typesToExport, param.t));
                                    switch param.t {
                                        case TInst(t, params):
                                            switch t.get().kind {
                                                case KTypeParameter(constraints):
                                                    if (constraints != null && constraints.length > 0) {
                                                        var constraintI = 0;
                                                        for (constraint in constraints) {
                                                            if (constraintI++ > 0) {
                                                                dts.add(' ');
                                                            }
                                                            dts.add(' extends ');
                                                            dts.add(typeToString(typesToExport, constraint));
                                                        }
                                                    }
                                                default:
                                            }
                                        default:
                                    }
                                }
                                dts.add('>');
                            }
                            dts.add(' {\n');
                            var hasConstructsWithParams = false;
                            var constructI = 0;
                            for (construct in enumType.constructs) {
                                if (construct.doc != null && construct.doc.trim() != '') {
                                    dts.add(tab);
                                    dts.add('/**');
                                    dts.add(construct.doc);
                                    dts.add('*/\n');
                                }
                                switch construct.type {
                                    case TFun(args, ret):
                                        hasConstructsWithParams = true;
                                    default:
                                        if (constructI++ > 0) {
                                            dts.add(',\n');
                                            dts.add(tab);
                                            dts.add(construct.name);
                                        }
                                        else {
                                            dts.add(tab);
                                            dts.add(construct.name);
                                        }
                                }
                            }
                            dts.add('\n');
                            dts.add('}\n\n');
                            if (hasConstructsWithParams) {
                                dts.add('namespace ');
                                dts.add(enumType.name);
                                dts.add(' {\n');
                                for (construct in enumType.constructs) {
                                    if (construct.doc != null && construct.doc.trim() != '') {
                                        dts.add(tab);
                                        dts.add('/**');
                                        dts.add(construct.doc);
                                        dts.add('*/\n');
                                    }
                                    switch construct.type {
                                        case TFun(args, ret):
                                            dts.add(tab);
                                            dts.add('export function ');
                                            dts.add(construct.name);
                                            dts.add('(');
                                            var i = 0;
                                            for (arg in args) {
                                                if (i > 0) {
                                                    dts.add(', ');
                                                }
                                                dts.add(arg.name);
                                                if (arg.opt)
                                                    dts.add('?');
                                                dts.add(': ');
                                                dts.add(typeToString(typesToExport, arg.t));
                                                i++;
                                            }
                                            dts.add('): ');
                                            dts.add(typeToString(typesToExport, ret));
                                            dts.add(';\n');
                                        default:
                                    }
                                }
                                dts.add('}\n\n');
                            }
                        case TInst(t, params):
                            var classType = t.get();
                            if (classType.doc != null && classType.doc.trim() != '') {
                                dts.add('/**');
                                dts.add(classType.doc);
                                dts.add('*/\n');
                            }
                            if (classType.isInterface || classType.name == 'Array') {
                                dts.add('interface ');
                            }
                            else {
                                dts.add('class ');
                            }
                            if (classType.name.startsWith('Scriptable')) {
                                dts.add(classType.name.substring('Scriptable'.length));
                            }
                            else {
                                dts.add(classType.name);
                            }
                            if (classType.params != null && classType.params.length > 0) {
                                dts.add('<');
                                var paramI = 0;
                                for (param in classType.params) {
                                    if (paramI++ > 0) {
                                        dts.add(', ');
                                    }
                                    dts.add(typeToString(typesToExport, param.t));
                                    switch param.t {
                                        case TInst(t, params):
                                            switch t.get().kind {
                                                case KTypeParameter(constraints):
                                                    if (constraints != null && constraints.length > 0) {
                                                        var constraintI = 0;
                                                        for (constraint in constraints) {
                                                            if (constraintI++ > 0) {
                                                                dts.add(' ');
                                                            }
                                                            dts.add(' extends ');
                                                            dts.add(typeToString(typesToExport, constraint));
                                                        }
                                                    }
                                                default:
                                            }
                                        default:
                                    }
                                }
                                dts.add('>');
                            }
                            if (classType.superClass != null) {
                                var superClassType = classType.superClass.t.get();
                                var superClassTypeStr;
                                if (superClassType.pack.length > 0) {
                                    superClassTypeStr = superClassType.pack.join('.') + '.' + superClassType.name;
                                }
                                else {
                                    superClassTypeStr = superClassType.name;
                                }
                                dts.add(' extends ');
                                dts.add(convertType(typesToExport, superClassTypeStr));
                                if (classType.superClass.params != null && classType.superClass.params.length > 0) {
                                    dts.add('<');
                                    var paramI = 0;
                                    for (param in classType.superClass.params) {
                                        if (paramI++ > 0)
                                            dts.add(', ');
                                        dts.add(typeToString(typesToExport, param));
                                    }
                                    dts.add('>');
                                }
                            }
                            if (classType.interfaces != null && classType.interfaces.length > 0) {
                                dts.add(' implements ');
                                var interfaceI = 0;
                                for (classInterface in classType.interfaces) {
                                    if (interfaceI++ > 0) {
                                        dts.add(', ');
                                    }
                                    var classInterfaceType = classInterface.t.get();
                                    var classInterfaceTypeStr;
                                    if (classInterfaceType.pack.length > 0) {
                                        classInterfaceTypeStr = classInterfaceType.pack.join('.') + '.' + classInterfaceType.name;
                                    }
                                    else {
                                        classInterfaceTypeStr = classInterfaceType.name;
                                    }
                                    dts.add(convertType(typesToExport, classInterfaceTypeStr));
                                }
                            }
                            dts.add(' {\n');
                            if (classType.constructor != null) {
                                var fieldNew = classType.constructor.get();
                                if (fieldNew.doc != null && fieldNew.doc.trim() != '') {
                                    dts.add(tab);
                                    dts.add('/**');
                                    dts.add(fieldNew.doc);
                                    dts.add('*/\n');
                                }
                                dts.add(tab);
                                dts.add('constructor(');
                                switch fieldNew.type {
                                    case TFun(args, ret):
                                        if (fieldNew.params != null && fieldNew.params.length > 0) {
                                            dts.add('<');
                                            var paramI = 0;
                                            for (param in fieldNew.params) {
                                                if (paramI++ > 0) {
                                                    dts.add(', ');
                                                }
                                                dts.add(typeToString(typesToExport, param.t));
                                            }
                                            dts.add('>');
                                        }
                                        var i = 0;
                                        for (arg in args) {
                                            if (i > 0) {
                                                dts.add(', ');
                                            }
                                            dts.add(arg.name);
                                            if (arg.opt)
                                                dts.add('?');
                                            dts.add(': ');
                                            dts.add(typeToString(typesToExport, arg.t));
                                            i++;
                                        }
                                    default:
                                }
                                dts.add(');\n');
                            }
                            var fieldI = 0;
                            for (list in [classType.statics.get(), classType.fields.get()]) {
                                var isStatic = (fieldI++ == 0);
                                for (field in list) {
                                    if (field.isPublic && !field.name.startsWith('_') && !field.meta.has(':noCompletion')) {
                                        if (field.doc != null && field.doc.trim() != '') {
                                            dts.add(tab);
                                            dts.add('/**');
                                            dts.add(field.doc);
                                            dts.add('*/\n');
                                        }
                                        dts.add(tab);
                                        if (isStatic)
                                            dts.add('static ');
                                        dts.add(field.name);
                                        switch field.kind {
                                            case FVar(read, write):
                                                dts.add(': ');
                                                dts.add(typeToString(typesToExport, field.type));
                                                dts.add(';\n');
                                            case FMethod(k):
                                                if (field.params != null && field.params.length > 0) {
                                                    dts.add('<');
                                                    var paramI = 0;
                                                    for (param in field.params) {
                                                        if (paramI++ > 0) {
                                                            dts.add(', ');
                                                        }
                                                        dts.add(typeToString(typesToExport, param.t));
                                                    }
                                                    dts.add('>');
                                                }
                                                switch field.type {
                                                    case TFun(args, ret):
                                                        dts.add('(');
                                                        var i = 0;
                                                        for (arg in args) {
                                                            if (i > 0) {
                                                                dts.add(', ');
                                                            }
                                                            dts.add(arg.name);
                                                            if (arg.opt)
                                                                dts.add('?');
                                                            dts.add(': ');
                                                            dts.add(typeToString(typesToExport, arg.t));
                                                            i++;
                                                        }
                                                        dts.add('): ');
                                                        dts.add(typeToString(typesToExport, ret));
                                                    default:
                                                }
                                                dts.add(';\n');
                                        }
                                    }
                                }
                            }
                            dts.add('}\n\n');
                        case TType(t, params):
                            var defType = t.get();
                            if (defType.doc != null && defType.doc.trim() != '') {
                                dts.add(tab);
                                dts.add('/**');
                                dts.add(defType.doc);
                                dts.add('*/\n');
                            }
                            switch defType.type {
                                case TAnonymous(a):
                                    dts.add('interface ');
                                default:
                                    dts.add('type ');
                            }
                            dts.add(defType.name);
                            if (defType.params != null && defType.params.length > 0) {
                                dts.add('<');
                                var paramI = 0;
                                for (param in defType.params) {
                                    if (paramI++ > 0) {
                                        dts.add(', ');
                                    }
                                    dts.add(typeToString(typesToExport, param.t));
                                    switch param.t {
                                        case TInst(t, params):
                                            switch t.get().kind {
                                                case KTypeParameter(constraints):
                                                    if (constraints != null && constraints.length > 0) {
                                                        var constraintI = 0;
                                                        for (constraint in constraints) {
                                                            if (constraintI++ > 0) {
                                                                dts.add(' ');
                                                            }
                                                            dts.add(' extends ');
                                                            dts.add(typeToString(typesToExport, constraint));
                                                        }
                                                    }
                                                default:
                                            }
                                        default:
                                    }
                                }
                                dts.add('>');
                            }
                            var parentFields = [];
                            switch defType.type {
                                case TAnonymous(a):
                                    dts.add(' {\n');
                                    var anon = a.get();
                                    switch anon.status {
                                        case AExtend(tl):
                                            for (parentDef in tl.get()) {
                                                switch parentDef {
                                                    case TAnonymous(a):
                                                        walkParentAnon(parentFields, a);
                                                    default:
                                                }
                                            }
                                        default:
                                    }
                                    for (field in parentFields.concat(anon.fields)) {
                                        if (field.isPublic && !field.name.startsWith('_') && !field.meta.has(':noCompletion')) {
                                            if (field.doc != null && field.doc.trim() != '') {
                                                dts.add(tab);
                                                dts.add('/**');
                                                dts.add(field.doc);
                                                dts.add('*/\n');
                                            }
                                            dts.add(tab);
                                            dts.add(field.name);
                                            if (field.meta.has(':optional')) {
                                                dts.add('?');
                                            }
                                            switch field.kind {
                                                case FVar(read, write):
                                                    dts.add(': ');
                                                    dts.add(typeToString(typesToExport, field.type));
                                                    dts.add(';\n');
                                                case FMethod(k):
                                                    if (field.params != null && field.params.length > 0) {
                                                        dts.add('<');
                                                        var paramI = 0;
                                                        for (param in field.params) {
                                                            if (paramI++ > 0) {
                                                                dts.add(', ');
                                                            }
                                                            dts.add(typeToString(typesToExport, param.t));
                                                        }
                                                        dts.add('>');
                                                    }
                                                    switch field.type {
                                                        case TFun(args, ret):
                                                            dts.add('(');
                                                            var i = 0;
                                                            for (arg in args) {
                                                                if (i > 0) {
                                                                    dts.add(', ');
                                                                }
                                                                dts.add(arg.name);
                                                                if (arg.opt)
                                                                    dts.add('?');
                                                                dts.add(': ');
                                                                dts.add(typeToString(typesToExport, arg.t));
                                                                i++;
                                                            }
                                                            dts.add('): ');
                                                            dts.add(typeToString(typesToExport, ret));
                                                        default:
                                                    }
                                                    dts.add(';\n');
                                            }
                                        }
                                    }
                                    dts.add('}\n\n');
                                default:
                                    dts.add(' = ');
                                    dts.add(typeToString(typesToExport, defType.type));
                                    dts.add(';\n\n');
                            }
                        case TFun(args, ret):
                        case TAnonymous(a):
                        case TDynamic(t):
                        case TLazy(f):
                        case TAbstract(t, params):
                            // TODO
                            //trace('TABSTRACT $t $params');
                            var type = t.get();
                            var impl = type.impl.get();
                            for (field in impl.statics.get()) {
                                //trace('field: ' + field.name);
                            }
                    }
                }
            }

            if (FileSystem.exists(exportPath)) {
                deleteRecursive(exportPath);
            }
            FileSystem.createDirectory(exportPath);
            File.saveContent(Path.join([exportPath, 'api.d.ts']), dts.toString());

        });

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END ExportApi.export()');
        #end

    }

/// Internal

    public static function getExportPath():String {

        var output = Compiler.getOutput();
        if (output != null) {
            var ext = Path.extension(output);
            if (ext != null && ext.trim() != '')
                return Path.join([Path.directory(output), outputSubPath]);
            else
                return Path.join([output, outputSubPath]);
        }
        return null;

    }

    public static function deleteRecursive(toDelete:String):Void {

        if (FileSystem.isDirectory(toDelete)) {

            for (name in FileSystem.readDirectory(toDelete)) {

                var path = Path.join([toDelete, name]);
                if (FileSystem.isDirectory(path)) {
                    deleteRecursive(path);
                } else {
                    FileSystem.deleteFile(path);
                }
            }

            FileSystem.deleteDirectory(toDelete);

        }
        else {

            FileSystem.deleteFile(toDelete);

        }

    }

    static function walkParentAnon(parentFields:Array<haxe.macro.Type.ClassField>, a:haxe.macro.Type.Ref<haxe.macro.Type.AnonType>):Void {
        var anon = a.get();
        switch anon.status {
            case AExtend(tl):
                for (parentDef in tl.get()) {
                    switch parentDef {
                        case TAnonymous(a):
                            walkParentAnon(parentFields, a);
                        default:
                    }
                }
            default:
        }
        for (field in anon.fields) {
            parentFields.push(field);
        }
    }

    static function complexTypeToString(typesToExport:Map<String, String>, type:ComplexType):String {

        var typeStr:String = null;

        if (type != null) {
            switch (type) {
                case TPath(p):
                    typeStr = p.name;
                    if (typeStr == 'StdTypes' && p.params != null) {
                        for (param in p.params) {
                            switch param {
                                case TPType(t):
                                    return complexTypeToString(typesToExport, t);
                                case TPExpr(e):
                                    return 'Dynamic';
                            }
                        }
                    }
                    if (p.pack != null && p.pack.length > 0) {
                        typeStr = p.pack.join('.') + '.' + typeStr;
                    }
                    if (p.params != null && p.params.length > 0) {
                        typeStr += '<';
                        var n = 0;
                        for (param in p.params) {
                            if (n > 0)
                                typeStr += ',';
                            switch param {
                                case TPType(t):
                                    var isStdType = false;
                                    switch t {
                                        case TPath(p):
                                            if (p.name == 'StdTypes') {
                                                isStdType = true;
                                                typeStr += p.sub;
                                            }
                                        default:
                                    }
                                    if (!isStdType)
                                        typeStr += convertType(typesToExport, complexTypeToString(typesToExport, t));
                                case TPExpr(e):
                                    typeStr += 'Dynamic';
                            }
                            n++;
                        }
                        typeStr += '>';
                    }
                default:
                    typeStr = 'Dynamic';
            }
        }
        else {
            typeStr = 'Dynamic';
        }

        return typeStr;

    }

    static function typeToString(typesToExport:Map<String, String>, type:haxe.macro.Type):String {

        var typeStr = 'Dynamic';

        switch type {
            case TMono(t):
                typeStr = 'TMono';
            case TEnum(t, params):
                var enumType = t.get();
                if (enumType.pack.length > 0) {
                    typeStr = enumType.pack.join('.') + '.' + enumType.name;
                }
                else {
                    typeStr = enumType.name;
                }
                typeStr = convertType(typesToExport, typeStr);
                if (params != null && params.length > 0) {
                    typeStr += '<' + typeParamsToString(typesToExport, params) + '>';
                }
            case TInst(t, params):
                var classType = t.get();
                if (classType.pack.length > 0) {
                    typeStr = classType.pack.join('.') + '.' + classType.name;
                }
                else {
                    typeStr = classType.name;
                }
                typeStr = convertType(typesToExport, typeStr);
                if (params != null && params.length > 0) {
                    typeStr += '<' + typeParamsToString(typesToExport, params) + '>';
                }
            case TType(t, params):
                typeStr = typeToString(typesToExport, t.get().type);
            case TFun(args, ret):
                typeStr = '((';
                var argI = 0;
                for (arg in args) {
                    if (argI++ > 0) {
                        typeStr += ', ';
                    }
                    if (arg.name != null && arg.name.length > 0) {
                        typeStr += arg.name;
                    }
                    else {
                        typeStr += 'arg$argI';
                    }
                    if (arg.opt) {
                        typeStr += '?';
                    }
                    typeStr += ': ';
                    typeStr += typeToString(typesToExport, arg.t);
                }
                typeStr += ') => ';
                typeStr += typeToString(typesToExport, ret);
                typeStr += ')';
            case TAnonymous(a):
                typeStr = 'TAnonymous';
            case TDynamic(t):
                typeStr = 'Dynamic';
            case TLazy(f):
                typeStr = typeToString(typesToExport, f());
            case TAbstract(t, params):
                var toStr = '' + t;
                var underlyingType = t.get().type;
                switch underlyingType {
                    case TAbstract(t, params):
                        var toStrUnder = '' + t;
                        if (toStr == toStrUnder) {
                            typeStr = toStr;
                        }
                    default:
                        typeStr = typeToString(typesToExport, t.get().type);
                }
                typeStr = convertType(typesToExport, toStr);
                if (params != null && params.length > 0) {
                    if (typeStr == 'Null') {
                        typeStr = typeParamsToString(typesToExport, params) + '?';
                    }
                    else {
                        typeStr += '<' + typeParamsToString(typesToExport, params) + '>';
                    }
                }
        }

        return typeStr;

        /*
        var typeStr = complexTypeToString(typesToExport, TypeTools.toComplexType(type));

        if (typeStr == 'StdTypes') {
            typeStr = ''+type.getParameters()[0];
        }

        return typeStr;
        */

    }

    static function typeParamsToString(typesToExport:Map<String, String>, params:Array<haxe.macro.Type>):String {

        if (params == null || params.length == 0)
            return '';
        var result = '';
        var i = 0;
        for (param in params) {
            if (i++ > 0)
                result += ', ';
            result += typeToString(typesToExport, param);
        }
        return result;

    }

    static function convertType(typesToExport:Map<String, String>, typeStr:String):String {

        if (typeStr.charAt(typeStr.length - 2) == '.') {
            typeStr = typeStr.charAt(typeStr.length - 1);
        }
        else if (typeStr.startsWith('ceramic.') && typesToExport.exists('ceramic.scriptable.Scriptable' + typeStr.substring('ceramic.'.length))) {
            typeStr = typesToExport.get('ceramic.scriptable.Scriptable' + typeStr.substring('ceramic.'.length));
            if (typeStr.startsWith('Scriptable')) {
                typeStr = typeStr.substring('Scriptable'.length);
            }
        }
        else if (typesToExport.exists(typeStr)) {
            typeStr = typesToExport.get(typeStr);
        }
        else if (typeStr.startsWith('ceramic.ReadOnly')) {
            typeStr = typeStr.substring('ceramic.ReadOnly'.length);
        }
        return typeStr;

    }

    static var RE_IMPORT = ~/^import\s+([^;\s]+)\s*(?:(?:as|in)\s*([^;\s]+)\s*)?;/;

}

#end
