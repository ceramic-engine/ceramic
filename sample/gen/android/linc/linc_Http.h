#include <hxcpp.h>
#include <jni.h>

namespace ceramic {

    namespace android {

        /** Send HTTP request */
        void Http_sendHttpRequest(::cpp::Pointer<void> class_, ::cpp::Pointer<void> method_, ::String params, ::Dynamic done);

        /** Download file */
        void Http_download(::cpp::Pointer<void> class_, ::cpp::Pointer<void> method_, ::String params, ::String targetPath, ::Dynamic done);

    }

}

extern "C" {

    JNIEXPORT void Java_ceramic_support_bind_1Http_callN_1StringVoid(JNIEnv *env, jclass clazz, jstring address, jstring arg1);

    JNIEXPORT void Java_ceramic_support_bind_1Http_callN_1MapVoid(JNIEnv *env, jclass clazz, jstring address, jstring arg1);

}

