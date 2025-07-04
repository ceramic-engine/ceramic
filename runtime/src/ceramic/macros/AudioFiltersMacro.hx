package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Printer;
import haxe.macro.Type;
import haxe.macro.TypeTools;

class AudioFiltersMacro {

    #if (macro && web)
    static var filterReferences:Array<{
        pack: Array<String>,
        name: String,
        filePath: String,
        hash: String,
        min: Int,
        max: Int
    }> = [];
    static var workletReferences:Array<{
        pack: Array<String>,
        name: String,
        filePath: String,
        hash: String,
        min: Int,
        max: Int
    }> = [];
    static var fileHashes:Map<String,String> = new Map();

    static function getHash(filePath:String):String {
        var hash = fileHashes.get(filePath);
        if (hash == null) {
            hash = haxe.crypto.Md5.encode(sys.io.File.getContent(filePath));
            fileHashes.set(filePath, hash);
        }
        return hash;
    }
    #end

    public static function init():Void {

        #if web
        var isCompletion = Context.defined('completion');
        if (!isCompletion) {
            Context.onAfterGenerate(function() {
                var targetPath = DefinesMacro.jsonDefinedValue('target_path');
                if (targetPath != null) {
                    filterReferences.sort(function(a, b) {
                        if (a.filePath < b.filePath) return -1;
                        if (a.filePath > b.filePath) return 1;
                        if (a.hash < b.hash) return -1;
                        if (a.hash > b.hash) return 1;
                        return 0;
                    });
                    workletReferences.sort(function(a, b) {
                        if (a.filePath < b.filePath) return -1;
                        if (a.filePath > b.filePath) return 1;
                        if (a.hash < b.hash) return -1;
                        if (a.hash > b.hash) return 1;
                        return 0;
                    });
                    if (!sys.FileSystem.exists(haxe.io.Path.join([targetPath, 'audio-filters']))) {
                        sys.FileSystem.createDirectory(haxe.io.Path.join([targetPath, 'audio-filters']));
                    }
                    sys.io.File.saveContent(haxe.io.Path.join([targetPath, 'audio-filters', 'info.json']), haxe.Json.stringify({
                        filters: filterReferences,
                        worklets: workletReferences
                    }));
                }
            });
        }
        #end

    }

    macro static public function buildFilter():Array<Field> {

        #if (web && ceramic_build_audio_worklets && !completion && !display)
        return [];
        #elseif (web && !completion && !display)
        final classRef = Context.getLocalClass().get();
        final classPos = Context.getPosInfos(classRef.pos);
        final filePath = Path.join([Sys.getCwd(), Context.getPosInfos(Context.currentPos()).file]);
        filterReferences.push({
            pack: [].concat(classRef.pack ?? []),
            name: classRef.name,
            filePath: filePath,
            hash: getHash(filePath),
            min: classPos.min,
            max: classPos.max
        });
        return processFilterParams(Context.getBuildFields());
        #else
        return processFilterParams(Context.getBuildFields());
        #end

    }

    macro static public function buildWorklet():Array<Field> {

        #if (web && ceramic_build_audio_worklets)
        return processWorkletParams(Context.getBuildFields());
        #elseif web
        var fields:Array<Field> = [];
        for (field in Context.getBuildFields()) {
            if (field.name == 'process') {
                fields.push({
                    name: field.name,
                    meta: field.meta,
                    pos: field.pos,
                    kind: switch field.kind {
                        case FFun(f):
                            FFun({
                                args: f.args,
                                params: f.params,
                                expr: macro {},
                                ret: null
                            });
                        case _: field.kind;
                    },
                    access: field.access
                });
            }
            else if (fieldHasParamMeta(field)) {
                fields.push(field);
            }
        }
        final classRef = Context.getLocalClass().get();
        final classPos = Context.getPosInfos(classRef.pos);
        final filePath = Path.join([Sys.getCwd(), Context.getPosInfos(Context.currentPos()).file]);
        workletReferences.push({
            pack: [].concat(classRef.pack ?? []),
            name: classRef.name,
            filePath: filePath,
            hash: getHash(filePath),
            min: classPos.min,
            max: classPos.max
        });
        return fields;
        #else
        return processWorkletParams(Context.getBuildFields());
        #end

    }

    static function processFilterParams(fields:Array<Field>):Array<Field> {

        var workletFields:Array<ClassField> = null;

        for (field in fields) {
            if (field.name == 'workletClass') {
                switch field.kind {
                    case FFun(f):
                        switch f.expr.expr {
                            case EReturn(e):
                                final complexType:ComplexType = exprToComplexType(e);
                                final type:Type = Context.resolveType(complexType, Context.currentPos());
                                switch type {
                                    case TInst(t, params):
                                        workletFields = t.get().fields.get();
                                    case _:
                                        throw new Error("workletClass() isn't returning a class type", field.pos);
                                }
                            case EBlock(exprs) if (exprs.length == 1):
                                switch exprs[0].expr {
                                    case EReturn(e):
                                        final complexType:ComplexType = exprToComplexType(e);
                                        final type:Type = Context.resolveType(complexType, Context.currentPos());
                                        switch type {
                                            case TInst(t, params):
                                                workletFields = t.get().fields.get();
                                            case _:
                                                throw new Error("workletClass() isn't returning a class type", field.pos);
                                        }
                                    case _:
                                        throw new Error("workletClass() should be in the format 'return YourFilterWorkletClass;'", field.pos);
                                }
                            case _:
                                throw new Error("workletClass() should be in the format 'return YourFilterWorkletClass;'", field.pos);
                        }
                    case _:
                        throw new Error("Invalid workletClass field", field.pos);
                }
            }
        }

        if (workletFields == null) {
            throw new Error("Failed to resolve worklet fields", Context.currentPos());
        }

        var paramIndex:Int = 0;
        var defaults:Array<String> = [];
        for (field in workletFields) {
            if (field.meta.has('param')) {
                switch field.kind {
                    case FVar(read, write):
                        final varType = TypeTools.toComplexType(field.type);
                        final defaultValExpr = field.expr()?.expr;
                        #if (display || completion)
                        fields.push({
                            name: field.name,
                            meta: field.meta.get(),
                            pos: field.pos,
                            doc: field.doc,
                            kind: FVar(varType, null),
                            access: [APublic]
                        });
                        #else
                        switch varType {
                            case TPath(p) if ((p.name == 'StdTypes' && (p.sub == 'Bool' || p.sub == 'Int' || p.sub == 'Float')) || p.name == 'Bool' || p.name == 'Int' || p.name == 'Float'):
                                final paramType:String = p.name == 'StdTypes' ? p.sub : p.name;
                                if (defaultValExpr != null) {
                                    switch defaultValExpr {
                                        case TConst(TBool(val)):
                                            defaults.push('${field.name} = ${val ? 'true' : 'false'};');
                                        case TConst(TInt(val)):
                                            defaults.push('${field.name} = $val;');
                                        case TConst(TFloat(val)):
                                            defaults.push('${field.name} = $val;');
                                        case _:
                                            throw 'Unsupported param default value: ' + defaultValExpr;
                                    }
                                }
                                fields.push({
                                    name: field.name,
                                    meta: field.meta.get(),
                                    pos: field.pos,
                                    doc: field.doc,
                                    kind: FProp('get', 'set', varType, null),
                                    access: [APublic]
                                });
                                fields.push({
                                    name: 'get_' + field.name,
                                    pos: field.pos,
                                    kind: FFun({
                                        args: [],
                                        ret: varType,
                                        expr: Context.parse('{
                                            return get$paramType($paramIndex);
                                        }', Context.currentPos())
                                    }),
                                    access: [APrivate]
                                });
                                fields.push({
                                    name: 'set_' + field.name,
                                    pos: field.pos,
                                    kind: FFun({
                                        args: [{
                                            name: 'value',
                                            type: varType
                                        }],
                                        ret: varType,
                                        expr: Context.parse('{
                                            set$paramType($paramIndex, value);
                                            return value;
                                        }', Context.currentPos())
                                    }),
                                    access: [APrivate]
                                });
                                paramIndex++;
                            case _:
                                throw new Error("Invalid audio filter param type: " + varType, field.pos);
                        }
                        #end
                    case FMethod(k):
                        throw new Error("Invalid audio filter param", field.pos);
                }
            }
        }

        if (defaults.length > 0) {
            fields.push({
                name: '_initDefaultParamValues',
                pos: Context.currentPos(),
                kind: FFun({
                    args: [],
                    expr: Context.parse('{
                    acquireParams();
                    ' + defaults.join('
                    ') +
                    'releaseParams();
                    }', Context.currentPos())
                }),
                access: [AOverride]
            });
        }

        if (paramIndex > 0) {
            fields.push({
                name: 'numParams',
                pos: Context.currentPos(),
                kind: FFun({
                    args: [],
                    expr: macro return $v{paramIndex},
                    ret: macro :Int
                }),
                access: [AOverride]
            });
        }

        return fields;

    }

    static function processWorkletParams(fields:Array<Field>):Array<Field> {

        var paramIndex:Int = 0;
        for (field in fields) {
            if (fieldHasParamMeta(field)) {
                switch field.kind {
                    case FVar(varType, e):
                        #if (display || completion)
                        // Nothing to do in that case
                        #else
                        switch varType {
                            case TPath(p) if ((p.name == 'StdTypes' && (p.sub == 'Bool' || p.sub == 'Int' || p.sub == 'Float')) || p.name == 'Bool' || p.name == 'Int' || p.name == 'Float'):
                                final paramType:String = p.name == 'StdTypes' ? p.sub : p.name;
                                field.kind = FProp('get', 'never', varType, null);
                                fields.push({
                                    name: 'get_' + field.name,
                                    pos: field.pos,
                                    kind: FFun({
                                        args: [],
                                        ret: varType,
                                        expr: Context.parse('{
                                            return get$paramType($paramIndex);
                                        }', Context.currentPos())
                                    }),
                                    access: [APrivate, AInline]
                                });
                                paramIndex++;
                            case _:
                                throw new Error("Invalid audio filter param type: " + varType, field.pos);
                        }
                        #end
                    case FProp(get, set, t, e):
                        throw new Error("Audio filter param cannot have custom getter or setter", field.pos);
                    case FFun(f):
                        throw new Error("Invalid audio filter param", field.pos);
                }
            }
        }

        return fields;

    }

    static function exprToComplexType(e:Expr):ComplexType {

        var printer = new Printer();
        var str = printer.printExpr(e);
        var pack = str.split('.');
        var name = pack.pop();
        return TPath({
            pack: pack,
            name: name
        });

    }

    static function fieldHasParamMeta(field:Field):Bool {

        if (field.meta == null || field.meta.length == 0) return false;

        for (meta in field.meta) {
            if (meta.name == 'param') {
                return true;
            }
        }

        return false;

    }

}