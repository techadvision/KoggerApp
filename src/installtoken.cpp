// InstallToken.cpp
#include "InstallToken.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QUuid>

#if defined(Q_OS_ANDROID)
static QString noBackupDirPath() {
    // Typical layout: /data/user/0/<pkg>/files  → sibling: /data/user/0/<pkg>/no_backup
    QString files = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation); // .../files
    QDir d(files);
    if (d.cdUp()) {                                // go to /data/user/0/<pkg>
        if (!d.exists("no_backup")) d.mkdir("no_backup");
        d.cd("no_backup");
        return d.absolutePath();
    }
    // Fallback: still use files (won’t survive restore, but better than nothing)
    return files;
}
#else
static QString noBackupDirPath() {
    // Non-Android: just keep it beside regular app data
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}
#endif

InstallToken::InstallToken(QObject* parent) : QObject(parent) {
    loadOrCreate();
}

void InstallToken::loadOrCreate() {
    const QString dirPath = noBackupDirPath();
    QDir dir(dirPath);
    if (!dir.exists()) dir.mkpath(".");

    QFile f(dir.filePath("install_salt.txt"));
    if (f.open(QIODevice::ReadOnly)) {
        salt_ = QString::fromUtf8(f.readAll()).trimmed();
        f.close();
    }
    if (salt_.isEmpty()) {
        salt_ = QUuid::createUuid().toString(QUuid::WithoutBraces);
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            f.write(salt_.toUtf8());
            f.close();
        }
    }
}
