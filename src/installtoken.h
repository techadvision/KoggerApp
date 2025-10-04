// InstallToken.h
#pragma once
#include <QObject>
#include <QString>

class InstallToken : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentSalt READ currentSalt CONSTANT)
public:
    explicit InstallToken(QObject* parent=nullptr);
    QString currentSalt() const { return salt_; }

private:
    QString salt_;
    void loadOrCreate();
};
