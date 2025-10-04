#include "SettingsBus.h"
#include <QThread>
#include <QMetaObject>

SettingsBus::SettingsBus(QObject* parent)
    : QObject(parent)
{
    runtimeTick_.setSingleShot(true);
    runtimeTick_.setInterval(0);
    connect(&runtimeTick_, &QTimer::timeout, this, &SettingsBus::flushRuntime);

    persistentTick_.setSingleShot(true);
    persistentTick_.setInterval(0);
    connect(&persistentTick_, &QTimer::timeout, this, &SettingsBus::flushPersistent);
}

// Public API — safe from any thread: re-post to our thread if needed.
void SettingsBus::updateRuntime(const QVariantMap& m)
{
    if (QThread::currentThread() != thread()) {
        QMetaObject::invokeMethod(this, [this, m]{ updateRuntime(m); }, Qt::QueuedConnection);
        return;
    }
    enqueueRuntime(m);
}

void SettingsBus::updatePersistent(const QVariantMap& m)
{
    if (QThread::currentThread() != thread()) {
        QMetaObject::invokeMethod(this, [this, m]{ updatePersistent(m); }, Qt::QueuedConnection);
        return;
    }
    enqueuePersistent(m);
}

// Coalesce multiple quick updates into one flush per event loop tick
void SettingsBus::enqueueRuntime(const QVariantMap& m)
{
    for (auto it = m.constBegin(); it != m.constEnd(); ++it)
        pendingRuntime_.insert(it.key(), it.value());
    if (!runtimeTick_.isActive()) runtimeTick_.start();
}

void SettingsBus::enqueuePersistent(const QVariantMap& m)
{
    for (auto it = m.constBegin(); it != m.constEnd(); ++it)
        pendingPersistent_.insert(it.key(), it.value());
    if (!persistentTick_.isActive()) persistentTick_.start();
}

// Diff & emit only changed keys
void SettingsBus::flushRuntime()
{
    if (pendingRuntime_.isEmpty()) return;

    QVariantMap changed;
    for (auto it = pendingRuntime_.constBegin(); it != pendingRuntime_.constEnd(); ++it) {
        const QString& k = it.key();
        const QVariant& v = it.value();
        if (runtime_.value(k) == v) continue;    // no-op
        runtime_[k] = v;
        changed.insert(k, v);
    }
    pendingRuntime_.clear();

    if (!changed.isEmpty())
        emit runtimeChanged(changed);
}

void SettingsBus::flushPersistent()
{
    if (pendingPersistent_.isEmpty()) return;

    QVariantMap changed;
    for (auto it = pendingPersistent_.constBegin(); it != pendingPersistent_.constEnd(); ++it) {
        const QString& k = it.key();
        const QVariant& v = it.value();
        if (persistent_.value(k) == v) continue; // no-op
        persistent_[k] = v;
        changed.insert(k, v);
    }
    pendingPersistent_.clear();

    if (!changed.isEmpty())
        emit persistentChanged(changed);
}

