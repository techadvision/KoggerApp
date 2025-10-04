#ifndef SETTINGSBUS_H
#define SETTINGSBUS_H

#pragma once
#include <QObject>
#include <QVariantMap>
#include <QTimer>

class SettingsBus : public QObject {
    Q_OBJECT
public:
    explicit SettingsBus(QObject* parent=nullptr);

    // QML/C++ entry points (same signatures as before)
    Q_INVOKABLE void updateRuntime(const QVariantMap& m);
    Q_INVOKABLE void updatePersistent(const QVariantMap& m);

    // Optional: handy snapshots (debugging/initial sync if you want)
    Q_INVOKABLE QVariantMap runtimeSnapshot() const { return runtime_; }
    Q_INVOKABLE QVariantMap persistentSnapshot() const { return persistent_; }

signals:
    // Emitted with *only* the keys that actually changed
    void runtimeChanged(const QVariantMap& m);
    void persistentChanged(const QVariantMap& m);

private:
    // Last known state
    QVariantMap runtime_;
    QVariantMap persistent_;

    // Coalescing buffers
    QVariantMap pendingRuntime_;
    QVariantMap pendingPersistent_;

    // Coalescing ticks (single-shot, fire at end of event loop)
    QTimer runtimeTick_;
    QTimer persistentTick_;

    // Helpers
    void enqueueRuntime(const QVariantMap& m);
    void enqueuePersistent(const QVariantMap& m);
    void flushRuntime();
    void flushPersistent();
};

/*
#pragma once
#include <QObject>
#include <QVariantMap>

class SettingsBus : public QObject {
    Q_OBJECT
public:
    explicit SettingsBus(QObject* parent=nullptr) : QObject(parent) {}

    Q_INVOKABLE void updateRuntime(const QVariantMap& m)    { emit runtimeChanged(m); }
    Q_INVOKABLE void updatePersistent(const QVariantMap& m) { emit persistentChanged(m); }

signals:
    void runtimeChanged(const QVariantMap& m);
    void persistentChanged(const QVariantMap& m);
};
*/

#endif // SETTINGSBUS_H
