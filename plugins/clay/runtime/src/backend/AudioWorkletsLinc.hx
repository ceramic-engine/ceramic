package backend;

import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.PositionTools;

/**
 * Build macro wiring the standalone `audio_worklets` library into the
 * hxcpp build (same pattern as linc libraries): adds a `@:buildXml` meta
 * that sets `LINC_AUDIO_WORKLETS_PATH` (the library root, resolved
 * relatively to the annotated class file) and `AUDIO_WORKLETS_OUT` (the
 * reflaxe.CPP output path, taken from the `audio_worklets_out` define
 * set by the clay build tools), then includes `linc/linc_audio_worklets.xml`.
 */
class AudioWorkletsLinc {

    macro public static function xml(_lib:String, _relative_root:String = '../'):Array<Field> {

        var _pos = Context.currentPos();
        var _pos_info = _pos.getInfos();
        var _class = Context.getLocalClass();

        var _source_path = Path.directory(_pos_info.file);
        if (!Path.isAbsolute(_source_path)) {
            _source_path = Path.join([Sys.getCwd(), _source_path]);
        }

        _source_path = Path.normalize(_source_path);

        var _linc_lib_path = Path.normalize(Path.join([_source_path, _relative_root]));
        var _linc_lib_var = 'LINC_${_lib.toUpperCase()}_PATH';

        var _out_path = Context.definedValue('audio_worklets_out');
        if (_out_path == null || _out_path.length == 0) {
            Context.error('Missing `audio_worklets_out` define (path of the transpiled audio worklets C++). It is set automatically by the clay build tools when `ceramic_standalone_audio_worklets` is enabled: run a project setup (`--setup`).', _pos);
        }

        var _define = '<set name="$_linc_lib_var" value="$_linc_lib_path/"/>';
        var _out_define = '<set name="AUDIO_WORKLETS_OUT" value="$_out_path"/>';
        var _import_path = '$${$_linc_lib_var}linc/linc_${_lib}.xml';
        var _import = '<include name="$_import_path" />';

        _class.get().meta.add(":buildXml", [{ expr: EConst(CString('$_define\n$_out_define\n$_import')), pos: _pos }], _pos);

        return Context.getBuildFields();

    }

}
