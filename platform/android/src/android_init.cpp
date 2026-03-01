#include "android_interface.h"

#include "android_serial.h"
#include "kogger_logging_category.h"

#include <QtCore/QJniEnvironment>
#include <QtCore/QJniObject>
#include <QtCore/QLoggingCategory>
#include <QMetaObject>
#include <QCoreApplication>
#include "InsetsHelper.h"
#include <QtCore/qnativeinterface.h>


KOGGER_LOGGING_CATEGORY(AndroidInitLog, "kogger.android.androidinit");

static jobject _context = nullptr;
static jobject _class_loader = nullptr;
static void notifyInsets_native(JNIEnv*, jclass, jint l, jint t, jint r, jint b, jint ime);
static void notifyDexState_native(JNIEnv*, jclass, jboolean enabled, jboolean fullscreen);
static bool registerInsetsDexNatives(JNIEnv *env, jobject activityObj);

static jboolean jniInit(JNIEnv *env, jobject context)
{
    qCDebug(AndroidInitLog) << Q_FUNC_INFO;

    const jclass context_cls = env->GetObjectClass(context);
    if (!context_cls) {
        return JNI_FALSE;
    }

    const jmethodID get_class_loader_id = env->GetMethodID(context_cls, "getClassLoader", "()Ljava/lang/ClassLoader;");
    if (QJniEnvironment::checkAndClearExceptions(env)) {
        return JNI_FALSE;
    }

    const jobject class_loader = env->CallObjectMethod(context, get_class_loader_id);
    if (QJniEnvironment::checkAndClearExceptions(env)) {
        return JNI_FALSE;
    }

    _context = env->NewGlobalRef(context);
    _class_loader = env->NewGlobalRef(class_loader);

    if (!registerInsetsDexNatives(env, context)) {
        qCWarning(AndroidInitLog) << "Failed to register notifyInsets/notifyDexState natives";
        (void) QJniEnvironment::checkAndClearExceptions(env);
        return JNI_FALSE;
    }

    return JNI_TRUE;
}

static jint jniSetNativeMethods()
{
    qCDebug(AndroidInitLog) << Q_FUNC_INFO;

    const JNINativeMethod javaMethods[] {
        {"nativeInit", "()Z", reinterpret_cast<void *>(jniInit)}
    };

    QJniEnvironment jniEnv;
    (void) jniEnv.checkAndClearExceptions();

    //jclass objectClass = jniEnv->FindClass(AndroidInterface::kJniKoggerActivityClassName);
    jclass objectClass = jniEnv->FindClass(AndroidInterface::kJniPulseActivityClassName);
    if (!objectClass) {
        //qCWarning(AndroidInitLog) << "Couldn't find class:" << AndroidInterface::kJniKoggerActivityClassName;
        qCWarning(AndroidInitLog) << "Couldn't find class:" << AndroidInterface::kJniPulseActivityClassName;
        (void) jniEnv.checkAndClearExceptions();
        return JNI_ERR;
    }

    const jint val = jniEnv->RegisterNatives(objectClass, javaMethods, std::size(javaMethods));
    if (val < 0) {
        qCWarning(AndroidInitLog) << "Error registering methods:" << val;
        (void) jniEnv.checkAndClearExceptions();
        return JNI_ERR;
    }

    qCDebug(AndroidInitLog) << "Main Native Functions Registered";

    (void) jniEnv.checkAndClearExceptions();

    return JNI_OK;
}

jint JNI_OnLoad(JavaVM *vm, void *reserved)
{
    Q_UNUSED(reserved);

    qCDebug(AndroidInitLog) << Q_FUNC_INFO;

    JNIEnv *env;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }

    if (jniSetNativeMethods() != JNI_OK) {
        return JNI_ERR;
    }

    AndroidInterface::setNativeMethods();


    AndroidSerial::setNativeMethods();


    QNativeInterface::QAndroidApplication::hideSplashScreen(333);

    return JNI_VERSION_1_6;
}

static void notifyInsets_native(JNIEnv*, jclass, jint l, jint t, jint r, jint b, jint ime)
{
    QMetaObject::invokeMethod(qApp, [=] {
        auto *ih = InsetsHelper::instance();
        if (ih->thread() != qApp->thread())
            ih->moveToThread(qApp->thread());
        ih->set(l, t, r, b, ime);
    }, Qt::QueuedConnection);
}

static void notifyDexState_native(JNIEnv*, jclass, jboolean enabled, jboolean fullscreen)
{
    QMetaObject::invokeMethod(qApp, [=] {
        auto *ih = InsetsHelper::instance();
        if (ih->thread() != qApp->thread())
            ih->moveToThread(qApp->thread());
        ih->setDex(enabled, fullscreen);
    }, Qt::QueuedConnection);
}

// Register natives on the *actual* Activity class instance we receive.
static bool registerInsetsDexNatives(JNIEnv *env, jobject activityObj)
{
    if (!activityObj)
        return false;

    jclass activityCls = env->GetObjectClass(activityObj);
    if (!activityCls)
        return false;

    const JNINativeMethod methods[] {
        { "notifyInsets",   "(IIIII)V", reinterpret_cast<void*>(notifyInsets_native) },
        { "notifyDexState", "(ZZ)V",    reinterpret_cast<void*>(notifyDexState_native) }
    };

    const jint rc = env->RegisterNatives(activityCls, methods, std::size(methods));
    return rc == 0;
}


