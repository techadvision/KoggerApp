// UiMetrics.h
#pragma once

#include <QObject>
#include <QtGlobal>

class UiMetrics : public QObject
{
    Q_OBJECT

    // Window size in *logical* QML units (ApplicationWindow.width/height)
    Q_PROPERTY(int windowWidth  READ windowWidth  WRITE setWindowWidth  NOTIFY windowSizeChanged)
    Q_PROPERTY(int windowHeight READ windowHeight WRITE setWindowHeight NOTIFY windowSizeChanged)

    // Overall scaling factor derived from window size
    Q_PROPERTY(qreal scale READ scale NOTIFY metricsChanged)

    // Margins / spacing
    Q_PROPERTY(int marginXS READ marginXS NOTIFY metricsChanged)
    Q_PROPERTY(int marginS  READ marginS  NOTIFY metricsChanged)
    Q_PROPERTY(int marginM  READ marginM  NOTIFY metricsChanged)
    Q_PROPERTY(int marginL  READ marginL  NOTIFY metricsChanged)

    // Font sizes (pixelSize, for QML and QFont::setPixelSize)
    Q_PROPERTY(int fontXS READ fontXS NOTIFY metricsChanged)
    Q_PROPERTY(int fontS  READ fontS  NOTIFY metricsChanged)
    Q_PROPERTY(int fontM  READ fontM  NOTIFY metricsChanged)
    Q_PROPERTY(int fontL  READ fontL  NOTIFY metricsChanged)
    Q_PROPERTY(int fontXL READ fontXL NOTIFY metricsChanged)

    // Icons
    // - iconTouch: tap targets (buttons)
    // - iconIllustration: small icons that don't need to be tappable
    Q_PROPERTY(int iconTouch        READ iconTouch        NOTIFY metricsChanged)
    Q_PROPERTY(int iconIllustration READ iconIllustration NOTIFY metricsChanged)

    // Scale factor you can apply to PNGs if you like
    Q_PROPERTY(qreal imageScale READ imageScale NOTIFY metricsChanged)

public:
    explicit UiMetrics(QObject *parent = nullptr);

    static UiMetrics* instance();
    static void setInstance(UiMetrics* instance);

    int windowWidth() const;
    void setWindowWidth(int w);

    int windowHeight() const;
    void setWindowHeight(int h);

    qreal scale() const;

    int marginXS() const;
    int marginS()  const;
    int marginM()  const;
    int marginL()  const;

    int fontXS() const;
    int fontS()  const;
    int fontM()  const;
    int fontL()  const;
    int fontXL() const;

    int iconTouch()        const;
    int iconIllustration() const;

    qreal imageScale() const;

signals:
    void windowSizeChanged();
    void metricsChanged();

private:
    static UiMetrics* s_instance;
    int m_windowWidth  = 1280;  // default / reference
    int m_windowHeight = 800;   // default / reference

    qreal computeScale() const;
};

