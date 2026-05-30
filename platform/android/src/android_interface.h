/****************************************************************************
 *
 * Copyright (C) 2018 Pinecone Inc. All rights reserved.
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QString>
#include <QtCore/QLoggingCategory>

#include <jni.h>

Q_DECLARE_LOGGING_CATEGORY(AndroidInterfaceLog)

namespace AndroidInterface
{
    bool cleanJavaException();
    jclass getActivityClass();
    void setNativeMethods();
    void jniLogDebug(JNIEnv *envA, jobject thizA, jstring messageA);
    void jniLogWarning(JNIEnv *envA, jobject thizA, jstring messageA);

    // Legacy storage helpers. Do not use for Google Play scoped-storage logging.
    bool checkStoragePermissions();
    QString getSDCardPath();

    // Pulse SAF-based log folder helpers.
    bool hasPulseLogFolderAccess();
    void requestPulseLogFolderAccess();
    int openPulseLogFileDescriptor(const QString &fileName,
                                   const QString &mimeType,
                                   bool append);

    void setKeepScreenOn(bool on);
    void moveTaskToBack();

    constexpr const char *kJniPulseActivityClassName = "org/techadvision/pulse/PulseActivity";
};
