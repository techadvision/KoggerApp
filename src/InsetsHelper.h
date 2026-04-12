#ifndef INSETSHELPER_H
#define INSETSHELPER_H

// InsetsHelper.h
#include <QObject>

class InsetsHelper : public QObject {
    Q_OBJECT
    Q_PROPERTY(int  left            READ left           NOTIFY insetsChanged)
    Q_PROPERTY(int  top             READ top            NOTIFY insetsChanged)
    Q_PROPERTY(int  right           READ right          NOTIFY insetsChanged)
    Q_PROPERTY(int  bottom          READ bottom         NOTIFY insetsChanged)
    Q_PROPERTY(int  ime             READ ime            NOTIFY insetsChanged)
    Q_PROPERTY(bool dexEnabled      READ dexEnabled     NOTIFY insetsChanged)
    Q_PROPERTY(bool dexFullscreen   READ dexFullscreen  NOTIFY insetsChanged)
public:
    static InsetsHelper* instance() { static InsetsHelper h; return &h; }
    int left() const { return L; }
    int top() const { return T; }
    int right() const { return R; }
    int bottom() const { return B; }
    int ime() const { return I; }

    bool dexEnabled()    const { return DexEnabled; }
    bool dexFullscreen() const { return DexFullscreen; }
public slots:
    void set(int l,int t,int r,int b,int i) { L=l;T=t;R=r;B=b;I=i; emit insetsChanged(); }
    void setDex(bool enabled, bool fullscreen) {
        DexEnabled = enabled;
        DexFullscreen = fullscreen;
        emit insetsChanged();
    }
signals:
    void insetsChanged();
private:
    int L=0,T=0,R=0,B=0,I=0;
    bool DexEnabled=false, DexFullscreen=false;
};

#endif // INSETSHELPER_H
