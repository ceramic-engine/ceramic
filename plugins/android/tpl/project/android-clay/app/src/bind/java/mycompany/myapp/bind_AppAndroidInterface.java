package mycompany.myapp;
// This file was generated with bind library

import bind.Support.*;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.os.Build;
import android.util.Log;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/** Java/Android interface */
@SuppressWarnings("all")
class bind_AppAndroidInterface {

    private static class bind_Result {
        Object value = null;
    }

    /** Get shared instance */
    public static AppAndroidInterface sharedInterface() {
        if (!bind.Support.isUIThread()) {
            final BindResult _bind_result = new BindResult();
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    synchronized(_bind_result) {
                        try {
                            _bind_result.value = bind_AppAndroidInterface.sharedInterface();
                        } catch (Throwable e) {
                            e.printStackTrace();
                        }
                        _bind_result.resolved = true;
                        _bind_result.notifyAll();
                    }
                }
            });
            synchronized(_bind_result) {
                if (!_bind_result.resolved) {
                    try {
                        _bind_result.wait();
                    } catch (Throwable e) {
                        e.printStackTrace();
                    }
                }
            }
            return (AppAndroidInterface) _bind_result.value;
        } else {
            final AppAndroidInterface return_java_ = AppAndroidInterface.sharedInterface();
            final AppAndroidInterface return_jni_ = (AppAndroidInterface) return_java_;
            return return_jni_;
        }
    }

    /** Constructor */
    public static AppAndroidInterface constructor() {
        if (!bind.Support.isUIThread()) {
            final BindResult _bind_result = new BindResult();
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    synchronized(_bind_result) {
                        try {
                            _bind_result.value = bind_AppAndroidInterface.constructor();
                        } catch (Throwable e) {
                            e.printStackTrace();
                        }
                        _bind_result.resolved = true;
                        _bind_result.notifyAll();
                    }
                }
            });
            synchronized(_bind_result) {
                if (!_bind_result.resolved) {
                    try {
                        _bind_result.wait();
                    } catch (Throwable e) {
                        e.printStackTrace();
                    }
                }
            }
            return (AppAndroidInterface) _bind_result.value;
        } else {
            final AppAndroidInterface return_java_ = new AppAndroidInterface();
            return return_java_;
        }
    }

    /** Say hello to `name` with a native Android dialog. Add a last name if any is known. */
    public static void hello(final AppAndroidInterface _instance, final String name, final String done) {
        if (!bind.Support.isUIThread()) {
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    bind_AppAndroidInterface.hello(_instance, name, done);
                }
            });
        } else {
            final String name_java_ = name;
            final HObject done_java_hobj_ = done == null ? null : new HObject(done);
            final Runnable done_java_ = done == null ? null : new Runnable() {
                public void run() {
                    bind.Support.runInNativeThread(new Runnable() {
                        public void run() {
                            bind_AppAndroidInterface.callN_Void(done_java_hobj_.address);
                        }
                    });
                }
            };
            _instance.hello(name_java_, done_java_);
        }
    }

    /** Get Android version string */
    public static String androidVersionString(final AppAndroidInterface _instance) {
        if (!bind.Support.isUIThread()) {
            final BindResult _bind_result = new BindResult();
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    synchronized(_bind_result) {
                        try {
                            _bind_result.value = bind_AppAndroidInterface.androidVersionString(_instance);
                        } catch (Throwable e) {
                            e.printStackTrace();
                        }
                        _bind_result.resolved = true;
                        _bind_result.notifyAll();
                    }
                }
            });
            synchronized(_bind_result) {
                if (!_bind_result.resolved) {
                    try {
                        _bind_result.wait();
                    } catch (Throwable e) {
                        e.printStackTrace();
                    }
                }
            }
            return (String) _bind_result.value;
        } else {
            final String return_java_ = _instance.androidVersionString();
            final String return_jni_ = return_java_;
            return return_jni_;
        }
    }

    /** Get Android version number */
    public static int androidVersionNumber(final AppAndroidInterface _instance) {
        if (!bind.Support.isUIThread()) {
            final BindResult _bind_result = new BindResult();
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    synchronized(_bind_result) {
                        try {
                            _bind_result.value = bind_AppAndroidInterface.androidVersionNumber(_instance);
                        } catch (Throwable e) {
                            e.printStackTrace();
                        }
                        _bind_result.resolved = true;
                        _bind_result.notifyAll();
                    }
                }
            });
            synchronized(_bind_result) {
                if (!_bind_result.resolved) {
                    try {
                        _bind_result.wait();
                    } catch (Throwable e) {
                        e.printStackTrace();
                    }
                }
            }
            return (int) _bind_result.value;
        } else {
            final int return_java_ = _instance.androidVersionNumber();
            final int return_jni_ = return_java_;
            return return_jni_;
        }
    }

    /** Dummy method to get Haxe types converted to Java types that then get returned back as an array. */
    public static String testTypes(final AppAndroidInterface _instance, final int aBool, final int anInt, final float aFloat, final String aList, final String aMap) {
        if (!bind.Support.isUIThread()) {
            final BindResult _bind_result = new BindResult();
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    synchronized(_bind_result) {
                        try {
                            _bind_result.value = bind_AppAndroidInterface.testTypes(_instance, aBool, anInt, aFloat, aList, aMap);
                        } catch (Throwable e) {
                            e.printStackTrace();
                        }
                        _bind_result.resolved = true;
                        _bind_result.notifyAll();
                    }
                }
            });
            synchronized(_bind_result) {
                if (!_bind_result.resolved) {
                    try {
                        _bind_result.wait();
                    } catch (Throwable e) {
                        e.printStackTrace();
                    }
                }
            }
            return (String) _bind_result.value;
        } else {
            final boolean aBool_java_ = aBool != 0;
            final int anInt_java_ = anInt;
            final float aFloat_java_ = aFloat;
            final List<Object> aList_java_ = (List<Object>) bind.Support.fromJSONString(aList);
            final Map<String,Object> aMap_java_ = (Map<String,Object>) bind.Support.fromJSONString(aMap);
            final List<Object> return_java_ = _instance.testTypes(aBool_java_, anInt_java_, aFloat_java_, aList_java_, aMap_java_);
            final String return_jni_ = bind.Support.toJSONString(return_java_);
            return return_jni_;
        }
    }

    /** If provided, will be called when main activity is paused */
    public static Object getOnPause(final AppAndroidInterface _instance) {
        if (!bind.Support.isUIThread()) {
            final BindResult _bind_result = new BindResult();
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    synchronized(_bind_result) {
                        try {
                            _bind_result.value = bind_AppAndroidInterface.getOnPause(_instance);
                        } catch (Throwable e) {
                            e.printStackTrace();
                        }
                        _bind_result.resolved = true;
                        _bind_result.notifyAll();
                    }
                }
            });
            synchronized(_bind_result) {
                if (!_bind_result.resolved) {
                    try {
                        _bind_result.wait();
                    } catch (Throwable e) {
                        e.printStackTrace();
                    }
                }
            }
            return (Object) _bind_result.value;
        } else {
            final Object return_java_ = _instance.onPause;
            final Object return_jni_ = return_java_;
            return return_jni_;
        }
    }

    /** If provided, will be called when main activity is paused */
    public static void setOnPause(final AppAndroidInterface _instance, final String onPause) {
        if (!bind.Support.isUIThread()) {
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    bind_AppAndroidInterface.setOnPause(_instance, onPause);
                }
            });
        } else {
            final HObject onPause_java_hobj_ = onPause == null ? null : new HObject(onPause);
            final Runnable onPause_java_ = onPause == null ? null : new Runnable() {
                public void run() {
                    bind.Support.runInNativeThread(new Runnable() {
                        public void run() {
                            bind_AppAndroidInterface.callN_Void(onPause_java_hobj_.address);
                        }
                    });
                }
            };
            _instance.onPause = onPause_java_;
        }
    }

    /** If provided, will be called when main activity is resumed */
    public static Object getOnResume(final AppAndroidInterface _instance) {
        if (!bind.Support.isUIThread()) {
            final BindResult _bind_result = new BindResult();
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    synchronized(_bind_result) {
                        try {
                            _bind_result.value = bind_AppAndroidInterface.getOnResume(_instance);
                        } catch (Throwable e) {
                            e.printStackTrace();
                        }
                        _bind_result.resolved = true;
                        _bind_result.notifyAll();
                    }
                }
            });
            synchronized(_bind_result) {
                if (!_bind_result.resolved) {
                    try {
                        _bind_result.wait();
                    } catch (Throwable e) {
                        e.printStackTrace();
                    }
                }
            }
            return (Object) _bind_result.value;
        } else {
            final Object return_java_ = _instance.onResume;
            final Object return_jni_ = return_java_;
            return return_jni_;
        }
    }

    /** If provided, will be called when main activity is resumed */
    public static void setOnResume(final AppAndroidInterface _instance, final String onResume) {
        if (!bind.Support.isUIThread()) {
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    bind_AppAndroidInterface.setOnResume(_instance, onResume);
                }
            });
        } else {
            final HObject onResume_java_hobj_ = onResume == null ? null : new HObject(onResume);
            final Runnable onResume_java_ = onResume == null ? null : new Runnable() {
                public void run() {
                    bind.Support.runInNativeThread(new Runnable() {
                        public void run() {
                            bind_AppAndroidInterface.callN_Void(onResume_java_hobj_.address);
                        }
                    });
                }
            };
            _instance.onResume = onResume_java_;
        }
    }

    /** Define a last name for hello() */
    public static String getLastName(final AppAndroidInterface _instance) {
        if (!bind.Support.isUIThread()) {
            final BindResult _bind_result = new BindResult();
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    synchronized(_bind_result) {
                        try {
                            _bind_result.value = bind_AppAndroidInterface.getLastName(_instance);
                        } catch (Throwable e) {
                            e.printStackTrace();
                        }
                        _bind_result.resolved = true;
                        _bind_result.notifyAll();
                    }
                }
            });
            synchronized(_bind_result) {
                if (!_bind_result.resolved) {
                    try {
                        _bind_result.wait();
                    } catch (Throwable e) {
                        e.printStackTrace();
                    }
                }
            }
            return (String) _bind_result.value;
        } else {
            final String return_java_ = _instance.lastName;
            final String return_jni_ = return_java_;
            return return_jni_;
        }
    }

    /** Define a last name for hello() */
    public static void setLastName(final AppAndroidInterface _instance, final String lastName) {
        if (!bind.Support.isUIThread()) {
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    bind_AppAndroidInterface.setLastName(_instance, lastName);
                }
            });
        } else {
            final String lastName_java_ = lastName;
            _instance.lastName = lastName_java_;
        }
    }

    public static void callJ_Void(final Object _callback) {
        if (!bind.Support.isUIThread()) {
            bind.Support.getUIThreadHandler().post(new Runnable() {
                public void run() {
                    bind_AppAndroidInterface.callJ_Void(_callback);
                }
            });
        } else {
            Runnable _callback_runnable = null;
            if (_callback instanceof Func0) {
                final Func0<Void> _callback_func0 = (Func0<Void>) _callback;
                _callback_runnable = new Runnable() {
                    public void run() {
                        _callback_func0.run();
                    }
                };
            } else {
                _callback_runnable = (Runnable) _callback;
            }
            _callback_runnable.run();
        }
    }

    static native void callN_Void(String address);

}

