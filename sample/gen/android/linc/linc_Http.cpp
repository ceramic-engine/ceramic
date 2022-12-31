#include "linc_JNI.h"
#include "linc_Http.h"
#ifndef INCLUDED_bind_java_HObject
#include <bind/java/HObject.h>
#endif

namespace ceramic {

    namespace android {

        /** Send HTTP request */
        void Http_sendHttpRequest(::cpp::Pointer<void> class_, ::cpp::Pointer<void> method_, ::String params, ::Dynamic done) {
            jstring params_jni_ = ::bind::jni::HxcppToJString(params);
            jstring done_jni_ = ::bind::jni::HObjectToJString(done);
            ::bind::jni::GetJNIEnv()->CallStaticVoidMethod((jclass) class_.ptr, (jmethodID) method_.ptr, params_jni_, done_jni_);
        }

        /** Download file */
        void Http_download(::cpp::Pointer<void> class_, ::cpp::Pointer<void> method_, ::String params, ::String targetPath, ::Dynamic done) {
            jstring params_jni_ = ::bind::jni::HxcppToJString(params);
            jstring targetPath_jni_ = ::bind::jni::HxcppToJString(targetPath);
            jstring done_jni_ = ::bind::jni::HObjectToJString(done);
            ::bind::jni::GetJNIEnv()->CallStaticVoidMethod((jclass) class_.ptr, (jmethodID) method_.ptr, params_jni_, targetPath_jni_, done_jni_);
        }

    }

}

extern "C" {

    JNIEXPORT void Java_ceramic_support_bind_1Http_callN_1StringVoid(JNIEnv *env, jclass clazz, jstring address, jstring arg1) {
        int haxe_stack_ = 99;
        hx::SetTopOfStack(&haxe_stack_, true);
        ::String arg1_hxcpp_ = ::bind::jni::JStringToHxcpp(arg1);
        ::Dynamic func_hobject_ = ::bind::jni::JStringToHObject(address);
        ::Dynamic func_unwrapped_ = ::bind::java::HObject_obj::unwrap(func_hobject_);
        func_unwrapped_->__run(arg1_hxcpp_);
        hx::SetTopOfStack((int *)0, true);
    }

    JNIEXPORT void Java_ceramic_support_bind_1Http_callN_1MapVoid(JNIEnv *env, jclass clazz, jstring address, jstring arg1) {
        int haxe_stack_ = 99;
        hx::SetTopOfStack(&haxe_stack_, true);
        ::String arg1_hxcpp_ = ::bind::jni::JStringToHxcpp(arg1);
        ::Dynamic func_hobject_ = ::bind::jni::JStringToHObject(address);
        ::Dynamic func_unwrapped_ = ::bind::java::HObject_obj::unwrap(func_hobject_);
        func_unwrapped_->__run(arg1_hxcpp_);
        hx::SetTopOfStack((int *)0, true);
    }

}

