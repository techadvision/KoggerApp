// UiMetrics.cpp
#include "UiMetrics.h"
#include <QtMath>

UiMetrics* UiMetrics::s_instance = nullptr;

UiMetrics* UiMetrics::instance()
{
    return s_instance;
}

void UiMetrics::setInstance(UiMetrics* instance)
{
    s_instance = instance;
}

UiMetrics::UiMetrics(QObject *parent)
    : QObject(parent)
{
}

int UiMetrics::windowWidth() const
{
    return m_windowWidth;
}

void UiMetrics::setWindowWidth(int w)
{
    if (w == m_windowWidth)
        return;

    m_windowWidth = w;
    emit windowSizeChanged();
    emit metricsChanged();
}

int UiMetrics::windowHeight() const
{
    return m_windowHeight;
}

void UiMetrics::setWindowHeight(int h)
{
    if (h == m_windowHeight)
        return;

    m_windowHeight = h;
    emit windowSizeChanged();
    emit metricsChanged();
}

qreal UiMetrics::computeScale() const
{
    // Reference: your main dev tablet in landscape.
    // Example: 1280x800 -> short side = 800
    const int refShortSide = 1200;

    int shortSide = qMin(m_windowWidth, m_windowHeight);
    if (shortSide <= 0)
        return 1.0;

    qreal s = shortSide / qreal(refShortSide);

    // Clamp so things don't get crazy on very small/large windows.
    const qreal minScale = 0.75;
    const qreal maxScale = 1.35;

    if (s < minScale) s = minScale;
    if (s > maxScale) s = maxScale;

    return s;
}

qreal UiMetrics::scale() const
{
    return computeScale();
}

// --- Margins ------------------------------------------------------------

int UiMetrics::marginXS() const
{
    return qRound(4 * computeScale());
}

int UiMetrics::marginS() const
{
    return qRound(8 * computeScale());
}

int UiMetrics::marginM() const
{
    return qRound(12 * computeScale());
}

int UiMetrics::marginL() const
{
    return qRound(16 * computeScale());
}

// --- Fonts --------------------------------------------------------------

int UiMetrics::fontXS() const
{
    return qRound(12 * computeScale());
}

int UiMetrics::fontS() const
{
    return qRound(18 * computeScale());
}

int UiMetrics::fontM() const
{
    return qRound(24 * computeScale());
}

int UiMetrics::fontL() const
{
    return qRound(30 * computeScale());
}

int UiMetrics::fontXL() const
{
    return qRound(36 * computeScale());
}

// --- Icons --------------------------------------------------------------

int UiMetrics::iconTouch() const
{
    // Design target 48×48 on reference window, but we allow some shrink
    qreal v = 64 * computeScale();
    const qreal min = 56;   // don't go smaller than this
    const qreal max = 72;

    if (v < min) v = min;
    if (v > max) v = max;

    return qRound(v);
}

int UiMetrics::iconTouchSmall() const
{
    // Design target 48×48 on reference window, but we allow some shrink
    qreal v = 52 * computeScale();
    const qreal min = 48;   // don't go smaller than this
    const qreal max = 72;

    if (v < min) v = min;
    if (v > max) v = max;

    return qRound(v);
}

int UiMetrics::iconIllustration() const
{
    // About half of iconTouch on reference; helpful for non-touch icons
    qreal v = 24 * computeScale();
    const qreal min = 16;
    const qreal max = 40;

    if (v < min) v = min;
    if (v > max) v = max;

    return qRound(v);
}

// --- PNG scaling --------------------------------------------------------

qreal UiMetrics::imageScale() const
{
    // For now just same as scale(), you can tweak if needed.
    return computeScale();
}
