#ifndef INSETSHELPER_H
#define INSETSHELPER_H

// InsetsHelper.h
#include <QObject>
#include <atomic>

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

    // THE FIRST INSETS ARRIVE BEFORE THERE IS AN APPLICATION TO DELIVER THEM TO.
    //
    // Android runs the activity's insets listener during onCreate and again from onResume,
    // and Qt only starts main() on the first global layout after that. So both deliveries
    // reach notifyInsets_native while qApp is still null, QMetaObject::invokeMethod(qApp,
    // ...) returns false, and the values are lost. Nothing sends them again until a
    // configuration change - so on an ordinary start every v2 surface read 0 for the
    // bottom bar, which is the Skydroid G30's clipped PAUSED and the loupe buttons under
    // its button bar.
    //
    // So the JNI side ALWAYS records the latest values here, on whatever thread it runs,
    // and main() applies them once the object lives on the GUI thread. Plain atomics, not
    // the QObject: touching the QObject from the Android UI thread before qApp exists would
    // give it the wrong thread affinity. When qApp does exist the queued set() still runs
    // as before, and it carries the same numbers, so the two paths cannot disagree.
    static void hold(int l, int t, int r, int b, int i) {
        heldL_ = l; heldT_ = t; heldR_ = r; heldB_ = b; heldI_ = i;
        heldInsets_ = true;
    }
    static void holdDex(bool enabled, bool fullscreen) {
        heldDexEnabled_ = enabled; heldDexFullscreen_ = fullscreen;
        heldDex_ = true;
    }
    // Returns true when anything had been held. Called once, from main(), on the GUI thread.
    bool applyHeld() {
        bool any = false;
        if (heldInsets_) { set(heldL_, heldT_, heldR_, heldB_, heldI_); any = true; }
        if (heldDex_)    { setDex(heldDexEnabled_, heldDexFullscreen_); any = true; }
        return any;
    }
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

    inline static std::atomic<int>  heldL_{0}, heldT_{0}, heldR_{0}, heldB_{0}, heldI_{0};
    inline static std::atomic<bool> heldInsets_{false};
    inline static std::atomic<bool> heldDexEnabled_{false}, heldDexFullscreen_{false};
    inline static std::atomic<bool> heldDex_{false};
};

#endif // INSETSHELPER_H
