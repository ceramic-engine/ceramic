package android;
// This file was generated with bind library

import bind.java.Support;
import cpp.Pointer;

class Http {

    private static var _jclassSignature = "ceramic/support/bind_Http";
    private static var _jclass:JClass = null;

    private var _instance:JObject = null;

    public function new() {}

    /** Send HTTP request */
    public static function sendHttpRequest(params:Dynamic, done:Dynamic->Void):Void {
        if (_jclass == null) _jclass = Support.resolveJClass(_jclassSignature);
        if (_mid_sendHttpRequest == null) _mid_sendHttpRequest = Support.resolveStaticJMethodID("ceramic/support/bind_Http", "sendHttpRequest", "(Ljava/lang/String;Ljava/lang/String;)V");
        var params_jni_ = haxe.Json.stringify(params);
        var done_jni_:HObject = null;
        if (done != null) {
            done_jni_ = new HObject(function(arg1_cl:String) {
                var arg1_cl_haxe_:Dynamic = haxe.Json.parse(arg1_cl);
                done(arg1_cl_haxe_);
            });
        }
        Http_Extern.sendHttpRequest(_jclass, _mid_sendHttpRequest, params_jni_, done_jni_);
    }
    private static var _mid_sendHttpRequest:JMethodID = null;

    /** Download file */
    public static function download(params:Dynamic, targetPath:String, done:String->Void):Void {
        if (_jclass == null) _jclass = Support.resolveJClass(_jclassSignature);
        if (_mid_download == null) _mid_download = Support.resolveStaticJMethodID("ceramic/support/bind_Http", "download", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
        var params_jni_ = haxe.Json.stringify(params);
        var targetPath_jni_ = targetPath;
        var done_jni_:HObject = null;
        if (done != null) {
            done_jni_ = new HObject(function(arg1_cl:String) {
                var arg1_cl_haxe_ = arg1_cl;
                done(arg1_cl_haxe_);
            });
        }
        Http_Extern.download(_jclass, _mid_download, params_jni_, targetPath_jni_, done_jni_);
    }
    private static var _mid_download:JMethodID = null;

}

@:keep
@:include('linc_Http.h')
#if !display
@:build(bind.Linc.touch())
@:build(bind.Linc.xml('Http', './'))
#end
@:allow(android.Http)
private extern class Http_Extern {

    @:native('ceramic::android::Http_sendHttpRequest')
    static function sendHttpRequest(class_:JClass, method_:JMethodID, params:String, done:HObject):Void;

    @:native('ceramic::android::Http_download')
    static function download(class_:JClass, method_:JMethodID, params:String, targetPath:String, done:HObject):Void;

}

