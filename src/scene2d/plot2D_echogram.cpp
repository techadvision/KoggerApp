#include "plot2D_echogram.h"
#include "plot2D.h"
#include "SettingsBus.h"
#include <numeric>


Plot2DEchogram::Plot2DEchogram()
{
    setThemeId(theme_);
    setLevels(low_, high_);
}

//Pulse
void Plot2DEchogram::setSettingsBus(SettingsBus* bus)
{
    bus_ = bus;
    // Optionally push the initial colors once the bus arrives:
    publishThemeColors();
}


void Plot2DEchogram::applyPersistent(const QVariantMap& m)
{
    bool levelsChanged = false;
    bool themeChanged  = false;

    if (m.contains("filterRealValue")) {
        const int v = m.value("filterRealValue").toInt();
        if (v != low_) { low_ = v; levelsChanged = true; }
    }
    if (m.contains("intensityRealValue")) {
        const int v = m.value("intensityRealValue").toInt();
        if (v != high_) { high_ = v; levelsChanged = true; }
    }
    if (m.contains("colorMapIndexReal")) {
        const int v = m.value("colorMapIndexReal").toInt();
        if (v != theme_) { theme_ = v; themeChanged = true; }
    }

    if (levelsChanged) setLevels(low_, high_);
    if (themeChanged)  setThemeId(theme_);
}

Plot2DEchogram::~Plot2DEchogram()
{
    delete miniPreviewPlot_;
}

void Plot2DEchogram::setLowLevel(float low)
{
    setLevels(low, _levels.high);
}

void Plot2DEchogram::setHightLevel(float high)
{
    setLevels(_levels.low, high);
}

void Plot2DEchogram::setLevels(float low, float high)
{
    _levels.low = low;
    _levels.high = high;
    updateColors();
}

void Plot2DEchogram::setColorScheme(QVector<QColor> coloros, QVector<int> levels) {

    const int M = coloros.size();
    if (M < 2 || M != levels.size())
        return;  // malformed inputs

    _colorTable.resize(256);

    // Build a full 256-entry blended table
    for (int v = 0; v < 256; ++v) {
        // 1) find which segment v lies in
        int i = 0;
        while (i < M-2 && v > levels[i+1]) ++i;

        // 2) fraction inside that bin
        float lo = levels[i];
        float hi = levels[i+1];
        float t  = (v - lo) / (hi - lo);

        // 3) blend the two endpoint colors
        const QColor &c0 = coloros[i];
        const QColor &c1 = coloros[i+1];
        int r = qRound(c0.red()   * (1 - t) + c1.red()   * t);
        int g = qRound(c0.green() * (1 - t) + c1.green() * t);
        int b = qRound(c0.blue()  * (1 - t) + c1.blue()  * t);

        // 4) store it
        _colorTable[v] = qRgb(r, g, b);
    }
    updateColors();
}


QVariantList Plot2DEchogram::getThemeColors() const
{
    QVariantList list;
    for (const QColor& c : _rawThemeColors){
        list.append(c.name());
    }
    return list;
}

void Plot2DEchogram::publishThemeColors()
{
    if (!bus_) return;
    QVariantList list;
    for (const QColor& c : _rawThemeColors){
        list.append(c.name());
    }
    // one batched update; your SettingsBus dedups unchanged keys already
    bus_->updateRuntime({ { "currentThemeColors", list } });

    // also notify QML bindings of the local Q_PROPERTY
    emit themeColorsChanged();
}


int Plot2DEchogram::getThemeId() const
{
    return static_cast<int>(themeId_);
}


void Plot2DEchogram::setThemeId(int theme_id) {

    if (theme_id >= ClassicTheme && theme_id <= PulseTheme_rainbow) {
    //if (theme_id >= ClassicTheme && theme_id <= MidnightTheme) {
        themeId_ = static_cast<ThemeId>(theme_id);
    }
    else {
        themeId_ = ClassicTheme;
    }

    QVector<QColor> coloros;
    QVector<int> levels;

    // ID 0
    if(theme_id == ClassicTheme) {
        coloros = {
                   QColor("#000000"),
                   QColor("#140551"),
                   QColor("#171b63"),
                   QColor("#1a2e74"),
                   QColor("#1f4184"),
                   QColor("#275493"),
                   QColor("#3267a2"),
                   QColor("#3f7aaf"),
                   QColor("#508ebb"),
                   QColor("#62a1c8"),
                   QColor("#77b5d4"),
                   QColor("#8dc9e0"),
                   QColor("#a4dced"),
                   QColor("#bdf0fa"),
                   QColor("#ffffff")};

        levels = {
            0, 18, 36, 55, 73, 91, 109, 128, 146, 164,
            182, 200, 219, 237, 255
        };

    }

    else if(theme_id == SepiaTheme) {
        coloros = {
           QColor("#000000"),
           QColor("#33320a"),
           QColor("#413f10"),
           QColor("#4f4c16"),
           QColor("#5e591b"),
           QColor("#6e6721"),
           QColor("#7e7427"),
           QColor("#8f832e"),
           QColor("#a09134"),
           QColor("#b29f3b"),
           QColor("#c5ae42"),
           QColor("#d8bd49"),
           QColor("#ebcc50"),
           QColor("#ffdb57"),
           QColor("#ffffff")};

        levels = {
            0, 18, 36, 55, 73, 91, 109, 128, 146, 164,
            182, 200, 219, 237, 255
        };


    } else if(theme_id == WBTheme) {

        coloros = {
           QColor("#000000"),
           QColor("#1a1a1a"),
           QColor("#2c2c2c"),
           QColor("#403f40"),
           QColor("#545355"),
           QColor("#69696b"),
           QColor("#7e7f82"),
           QColor("#939699"),
           QColor("#a9aeb0"),
           QColor("#c0c6c8"),
           QColor("#d7dfdf"),
           QColor("#ffffff")};

        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };


    } else if(theme_id == RedTheme) {

        coloros = {
           QColor("#000000"),
           QColor("#1b0f08"),
           QColor("#2f1a11"),
           QColor("#462417"),
           QColor("#5d2e1c"),
           QColor("#763821"),
           QColor("#904226"),
           QColor("#aa4d2c"),
           QColor("#c55731"),
           QColor("#e16237"),
           QColor("#e16237"),
           QColor("#fd9e81")};

        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };

    } else if(theme_id == GreenTheme) {

        coloros = {
           QColor("#000000"),
           QColor("#10160d"),
           QColor("#1b2917"),
           QColor("#253d1e"),
           QColor("#2f5226"),
           QColor("#39682e"),
           QColor("#437e36"),
           QColor("#4e963e"),
           QColor("#58ae46"),
           QColor("#62c74e"),
           QColor("#6de156"),
           QColor("#a1ed9c")};

        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };


    } else if (theme_id == Ek500BlackTheme) {
        coloros = {
            // extra “zero‐reflection” black
            QColor::fromRgb(  0,   0,   96),
            // EK500 palette
            QColor::fromRgb(159, 159, 159),
            QColor::fromRgb( 95,  95,  95),
            QColor::fromRgb(  0,   0, 255),
            QColor::fromRgb(  0,   0, 127),
            QColor::fromRgb(  0, 191,   0),
            QColor::fromRgb(  0, 127,   0),
            QColor::fromRgb(255, 255,   0),
            QColor::fromRgb(255, 127,   0),
            QColor::fromRgb(255,   0, 191),
            QColor::fromRgb(255,   0,   0),
            QColor::fromRgb(166,  83,  60),
            QColor::fromRgb(120,  60,  40)
        };

        // 13 levels evenly spaced from 0 → 255 (step ≈ 21.25, rounded)

        levels = {
            0,  21,  43,  64,  85, 106,
            128, 149, 170, 191, 213, 234, 255
        };

    }

    else if (theme_id == Ek500WhiteTheme) {
        coloros = {
            // extra “zero‐reflection” white or very light gray
            QColor::fromRgb(210, 210, 210),
            // EK500 palette
            QColor::fromRgb(159, 159, 159),
            QColor::fromRgb( 95,  95,  95),
            QColor::fromRgb(  0,   0, 255),
            QColor::fromRgb(  0,   0, 127),
            QColor::fromRgb(  0, 191,   0),
            QColor::fromRgb(  0, 127,   0),
            QColor::fromRgb(255, 255,   0),
            QColor::fromRgb(255, 127,   0),
            QColor::fromRgb(255,   0, 191),
            QColor::fromRgb(255,   0,   0),
            QColor::fromRgb(166,  83,  60),
            QColor::fromRgb(120,  60,  40)
        };

        levels = {
            0,  21,  43,  64,  85, 106,
            128, 149, 170, 191, 213, 234, 255
        };
    }

    else if(theme_id == Ek80BlackTheme) {
        //This is the EK80, black edition
        coloros = {
            QColor::fromRgb(  0,   0,   0),
            QColor::fromRgb(156, 138, 168),
            QColor::fromRgb(141, 125, 150),
            QColor::fromRgb(126, 113, 132),
            QColor::fromRgb(112, 100, 114),
            QColor::fromRgb(97,  88,  96),
            QColor::fromRgb(82,  76,  78),
            QColor::fromRgb(68,  76,  94),
            QColor::fromRgb(53,  83, 129),
            QColor::fromRgb(39,  90, 163),
            QColor::fromRgb(24,  96, 197),
            QColor::fromRgb( 9, 103, 232),
            QColor::fromRgb( 9, 102, 249),
            QColor::fromRgb( 9,  84, 234),
            QColor::fromRgb(15,  66, 219),
            QColor::fromRgb(22,  48, 204),
            QColor::fromRgb(29,  30, 189),
            QColor::fromRgb(36,  12, 174),
            QColor::fromRgb(37,  49, 165),
            QColor::fromRgb(38,  86, 156),
            QColor::fromRgb(39, 123, 147),
            QColor::fromRgb(40, 160, 138),
            QColor::fromRgb(41, 197, 129),
            QColor::fromRgb(37, 200, 122),
            QColor::fromRgb(30, 185, 116),
            QColor::fromRgb(24, 171, 111),
            QColor::fromRgb(17, 156, 105),
            QColor::fromRgb(10, 141,  99),
            QColor::fromRgb(21, 139,  92),
            QColor::fromRgb(68, 162,  82),
            QColor::fromRgb(114,185,  72),
            QColor::fromRgb(161,208,  62),
            QColor::fromRgb(208,231,  52),
            QColor::fromRgb(255,255,  42),
            QColor::fromRgb(254,229,  43),
            QColor::fromRgb(253,204,  44),
            QColor::fromRgb(253,179,  45),
            QColor::fromRgb(252,153,  46),
            QColor::fromRgb(252,128,  47),
            QColor::fromRgb(252,116,  63),
            QColor::fromRgb(252,110,  85),
            QColor::fromRgb(252,105, 108),
            QColor::fromRgb(252, 99, 130),
            QColor::fromRgb(252, 93, 153),
            QColor::fromRgb(252, 85, 160),
            QColor::fromRgb(252, 73, 139),
            QColor::fromRgb(253, 61, 118),
            QColor::fromRgb(253, 48,  96),
            QColor::fromRgb(254, 36,  75),
            QColor::fromRgb(255, 24,  54),
            QColor::fromRgb(240, 30,  52),
            QColor::fromRgb(226, 37,  51),
            QColor::fromRgb(212, 44,  50),
            QColor::fromRgb(198, 51,  49),
            QColor::fromRgb(184, 57,  48),
            QColor::fromRgb(176, 57,  49),
            QColor::fromRgb(170, 54,  51),
            QColor::fromRgb(165, 51,  54),
            QColor::fromRgb(159, 47,  56),
            QColor::fromRgb(153, 44,  58),
            QColor::fromRgb(150, 39,  56),
            QColor::fromRgb(151, 31,  45),
            QColor::fromRgb(153, 23,  33),
            QColor::fromRgb(154, 15,  22),
            QColor::fromRgb(155,  7,  11)
        };

        levels = {
            0,  4,  8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60,
            64, 68, 72, 76, 80, 84, 88, 92, 96,100,104,108,112,116,120,124,
            128,131,135,139,143,147,151,155,159,163,167,171,175,179,183,187,
            191,195,199,203,207,211,215,219,223,227,231,235,239,243,247,251,
            255
        };


    }

    else if(theme_id == Ek80WhiteTheme) {

        //This is the EK80, white edition
        coloros = {
            QColor::fromRgb(255, 255, 255),
            QColor::fromRgb(156, 138, 168),
            QColor::fromRgb(141, 125, 150),
            QColor::fromRgb(126, 113, 132),
            QColor::fromRgb(112, 100, 114),
            QColor::fromRgb(97,  88,  96),
            QColor::fromRgb(82,  76,  78),
            QColor::fromRgb(68,  76,  94),
            QColor::fromRgb(53,  83, 129),
            QColor::fromRgb(39,  90, 163),
            QColor::fromRgb(24,  96, 197),
            QColor::fromRgb( 9, 103, 232),
            QColor::fromRgb( 9, 102, 249),
            QColor::fromRgb( 9,  84, 234),
            QColor::fromRgb(15,  66, 219),
            QColor::fromRgb(22,  48, 204),
            QColor::fromRgb(29,  30, 189),
            QColor::fromRgb(36,  12, 174),
            QColor::fromRgb(37,  49, 165),
            QColor::fromRgb(38,  86, 156),
            QColor::fromRgb(39, 123, 147),
            QColor::fromRgb(40, 160, 138),
            QColor::fromRgb(41, 197, 129),
            QColor::fromRgb(37, 200, 122),
            QColor::fromRgb(30, 185, 116),
            QColor::fromRgb(24, 171, 111),
            QColor::fromRgb(17, 156, 105),
            QColor::fromRgb(10, 141,  99),
            QColor::fromRgb(21, 139,  92),
            QColor::fromRgb(68, 162,  82),
            QColor::fromRgb(114,185,  72),
            QColor::fromRgb(161,208,  62),
            QColor::fromRgb(208,231,  52),
            QColor::fromRgb(255,255,  42),
            QColor::fromRgb(254,229,  43),
            QColor::fromRgb(253,204,  44),
            QColor::fromRgb(253,179,  45),
            QColor::fromRgb(252,153,  46),
            QColor::fromRgb(252,128,  47),
            QColor::fromRgb(252,116,  63),
            QColor::fromRgb(252,110,  85),
            QColor::fromRgb(252,105, 108),
            QColor::fromRgb(252, 99, 130),
            QColor::fromRgb(252, 93, 153),
            QColor::fromRgb(252, 85, 160),
            QColor::fromRgb(252, 73, 139),
            QColor::fromRgb(253, 61, 118),
            QColor::fromRgb(253, 48,  96),
            QColor::fromRgb(254, 36,  75),
            QColor::fromRgb(255, 24,  54),
            QColor::fromRgb(240, 30,  52),
            QColor::fromRgb(226, 37,  51),
            QColor::fromRgb(212, 44,  50),
            QColor::fromRgb(198, 51,  49),
            QColor::fromRgb(184, 57,  48),
            QColor::fromRgb(176, 57,  49),
            QColor::fromRgb(170, 54,  51),
            QColor::fromRgb(165, 51,  54),
            QColor::fromRgb(159, 47,  56),
            QColor::fromRgb(153, 44,  58),
            QColor::fromRgb(150, 39,  56),
            QColor::fromRgb(151, 31,  45),
            QColor::fromRgb(153, 23,  33),
            QColor::fromRgb(154, 15,  22),
            QColor::fromRgb(155,  7,  11)
        };

        levels = {
            0,  4,  8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60,
            64, 68, 72, 76, 80, 84, 88, 92, 96,100,104,108,112,116,120,124,
            128,131,135,139,143,147,151,155,159,163,167,171,175,179,183,187,
            191,195,199,203,207,211,215,219,223,227,231,235,239,243,247,251,
            255
        };


    }

    else if(theme_id == FurunoBlackTheme) {

        coloros = {
           QColor::fromRgb(  0,   0,   0),
           QColor::fromRgb( 43, 126, 128),
           QColor::fromRgb(  0,   0, 255),
           QColor::fromRgb(127, 252, 254),
           QColor::fromRgb(  0, 128, 112),
           QColor::fromRgb(  0, 160,   0),
           QColor::fromRgb(  0, 255,   0),
           QColor::fromRgb(235, 254,   0),
           QColor::fromRgb(254, 191, 127),
           QColor::fromRgb(254, 128,   1),
           QColor::fromRgb(255,   0,   0),
           QColor::fromRgb(147,   0,   0)};

        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };


    }

    else if(theme_id == FurunoWhiteTheme) {

        coloros = {
            QColor::fromRgb(255, 255, 255),
            QColor::fromRgb( 43, 126, 128),
            QColor::fromRgb(  0,   0, 255),
            QColor::fromRgb(127, 252, 254),
            QColor::fromRgb(  0, 128, 112),
            QColor::fromRgb(  0, 160,   0),
            QColor::fromRgb(  0, 255,   0),
            QColor::fromRgb(235, 254,   0),
            QColor::fromRgb(254, 191, 127),
            QColor::fromRgb(254, 128,   1),
            QColor::fromRgb(255,   0,   0),
            QColor::fromRgb(147,   0,   0)};

        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };

    } else if (theme_id == Dt4BlackTheme) {
        coloros = {
            // extra “zero‐reflection” black
            //QColor::fromRgb(  0,   0,   0),
            // original DT4 colours
            QColor::fromRgb(  0,   0,   0),
            QColor::fromRgb( 61,  24,  49),
            QColor::fromRgb( 64,   0, 128),
            QColor::fromRgb( 32,   0, 192),
            QColor::fromRgb(  0,   0, 255),
            QColor::fromRgb(  0, 128, 255),
            QColor::fromRgb( 21, 234, 234),
            QColor::fromRgb( 14, 241, 156),
            QColor::fromRgb(  7, 248,  78),
            QColor::fromRgb(  0, 255,   0),
            QColor::fromRgb( 85, 255,   0),
            QColor::fromRgb(170, 255,   0),
            QColor::fromRgb(255, 255,   0),
            QColor::fromRgb(255, 191,   0),
            QColor::fromRgb(255, 128,   0),
            QColor::fromRgb(255,   0,   0)
        };

        //16 levels DT4 original
        levels = {
            0, 17, 34, 51, 68, 85, 102, 119, 136, 153,
            170, 187, 204, 221, 238, 255
        };


    }

    else if (theme_id == Dt4WhiteTheme) {
        coloros = {
            // extra “zero‐reflection” white
            QColor::fromRgb(255, 255, 255),
            // original DT4 colours
            QColor::fromRgb(  0,   0,   0),
            QColor::fromRgb( 61,  24,  49),
            QColor::fromRgb( 64,   0, 128),
            QColor::fromRgb( 32,   0, 192),
            QColor::fromRgb(  0,   0, 255),
            QColor::fromRgb(  0, 128, 255),
            QColor::fromRgb( 21, 234, 234),
            QColor::fromRgb( 14, 241, 156),
            QColor::fromRgb(  7, 248,  78),
            QColor::fromRgb(  0, 255,   0),
            QColor::fromRgb( 85, 255,   0),
            QColor::fromRgb(170, 255,   0),
            QColor::fromRgb(255, 255,   0),
            QColor::fromRgb(255, 191,   0),
            QColor::fromRgb(255, 128,   0),
            QColor::fromRgb(255,   0,   0)
        };

        levels = {  0,  16,  32,  48,  64,
                  80,  96, 112, 128, 143,
                  159, 175, 191, 207, 223,
                  239, 255 };

    }

    else if (theme_id == HtiBlackTheme) {
        coloros = {
            // extra “zero‐reflection” black (dark blue)
            QColor::fromRgb(  0,   0,   96),
            // HTI palette
            QColor::fromRgb(  0,   0, 255),
            QColor::fromRgb(  0,  32, 255),
            QColor::fromRgb(  0,  64, 255),
            QColor::fromRgb(  0,  96, 255),
            QColor::fromRgb(  0, 128, 255),
            QColor::fromRgb(  0, 159, 255),
            QColor::fromRgb(  0, 191, 255),
            QColor::fromRgb(  0, 223, 255),
            QColor::fromRgb(  0, 255, 255),
            QColor::fromRgb( 42, 255, 211),
            QColor::fromRgb( 84, 255, 167),
            QColor::fromRgb(125, 255, 123),
            QColor::fromRgb(167, 255,  79),
            QColor::fromRgb(182, 255,  66),
            QColor::fromRgb(196, 255,  53),
            QColor::fromRgb(211, 255,  39),
            QColor::fromRgb(226, 255,  26),
            QColor::fromRgb(240, 255,  13),
            QColor::fromRgb(255, 255,   0),
            QColor::fromRgb(255, 219,   0),
            QColor::fromRgb(255, 182,   0),
            QColor::fromRgb(255, 146,   0),
            QColor::fromRgb(255, 109,   0),
            QColor::fromRgb(255,  73,   0),
            QColor::fromRgb(255,  36,   0),
            QColor::fromRgb(255,   0,   0),
            QColor::fromRgb(255,   0,  64),
            QColor::fromRgb(255,   0, 128),
            QColor::fromRgb(255,   0, 191),
            QColor::fromRgb(255,   0, 255),
            QColor::fromRgb(255, 128, 255)
        };


        levels = {
            0,   8,  16,  25,  33,  41,  49,  58,
            66,  74,  82,  90,  99, 107, 115, 123,
            132, 140, 148, 156, 165, 173, 181, 189,
            197, 206, 214, 222, 230, 239, 247, 255
        };

    }

    else if (theme_id == HtiWhiteTheme) {
        coloros = {
            // extra “zero‐reflection” white
            QColor::fromRgb(255, 255, 255),
            // HTI palette
            QColor::fromRgb(  0,   0, 255),
            QColor::fromRgb(  0,  32, 255),
            QColor::fromRgb(  0,  64, 255),
            QColor::fromRgb(  0,  96, 255),
            QColor::fromRgb(  0, 128, 255),
            QColor::fromRgb(  0, 159, 255),
            QColor::fromRgb(  0, 191, 255),
            QColor::fromRgb(  0, 223, 255),
            QColor::fromRgb(  0, 255, 255),
            QColor::fromRgb( 42, 255, 211),
            QColor::fromRgb( 84, 255, 167),
            QColor::fromRgb(125, 255, 123),
            QColor::fromRgb(167, 255,  79),
            QColor::fromRgb(182, 255,  66),
            QColor::fromRgb(196, 255,  53),
            QColor::fromRgb(211, 255,  39),
            QColor::fromRgb(226, 255,  26),
            QColor::fromRgb(240, 255,  13),
            QColor::fromRgb(255, 255,   0),
            QColor::fromRgb(255, 219,   0),
            QColor::fromRgb(255, 182,   0),
            QColor::fromRgb(255, 146,   0),
            QColor::fromRgb(255, 109,   0),
            QColor::fromRgb(255,  73,   0),
            QColor::fromRgb(255,  36,   0),
            QColor::fromRgb(255,   0,   0),
            QColor::fromRgb(255,   0,  64),
            QColor::fromRgb(255,   0, 128),
            QColor::fromRgb(255,   0, 191),
            QColor::fromRgb(255,   0, 255),
            QColor::fromRgb(255, 128, 255)
        };

        levels = {
            0,   8,  16,  25,  33,  41,  49,  58,
            66,  74,  82,  90,  99, 107, 115, 123,
            132, 140, 148, 156, 165, 173, 181, 189,
            197, 206, 214, 222, 230, 239, 247, 255
        };

    }

    else if (theme_id == LsssBlackTheme) {
        /* experiment: TURBO */
        coloros = {
            QColor::fromRgb(48, 18, 59),
            QColor::fromRgb(54, 33, 95),
            QColor::fromRgb(59, 47, 128),
            QColor::fromRgb(63, 62, 156),
            QColor::fromRgb(66, 75, 181),
            QColor::fromRgb(69, 89, 203),
            QColor::fromRgb(70, 102, 221),
            QColor::fromRgb(71, 115, 235),
            QColor::fromRgb(70, 128, 246),
            QColor::fromRgb(68, 143, 254),
            QColor::fromRgb(62, 155, 254),
            QColor::fromRgb(55, 168, 250),
            QColor::fromRgb(46, 180, 242),
            QColor::fromRgb(37, 192, 231),
            QColor::fromRgb(30, 203, 218),
            QColor::fromRgb(25, 213, 205),
            QColor::fromRgb(24, 222, 192),
            QColor::fromRgb(29, 231, 178),
            QColor::fromRgb(39, 238, 164),
            QColor::fromRgb(53, 243, 148),
            QColor::fromRgb(70, 248, 132),
            QColor::fromRgb(89, 251, 115),
            QColor::fromRgb(109, 254, 98),
            QColor::fromRgb(128, 255, 83),
            QColor::fromRgb(146, 255, 71),
            QColor::fromRgb(164, 252, 60),
            QColor::fromRgb(177, 249, 54),
            QColor::fromRgb(190, 244, 52),
            QColor::fromRgb(203, 237, 52),
            QColor::fromRgb(215, 229, 53),
            QColor::fromRgb(225, 221, 55),
            QColor::fromRgb(235, 211, 57),
            QColor::fromRgb(242, 201, 58),
            QColor::fromRgb(248, 190, 57),
            QColor::fromRgb(252, 177, 54),
            QColor::fromRgb(254, 164, 49),
            QColor::fromRgb(254, 150, 43),
            QColor::fromRgb(252, 135, 37),
            QColor::fromRgb(249, 120, 30),
            QColor::fromRgb(245, 105, 24),
            QColor::fromRgb(240, 91, 18),
            QColor::fromRgb(234, 78, 13),
            QColor::fromRgb(225, 65, 9),
            QColor::fromRgb(216, 55, 6),
            QColor::fromRgb(206, 45, 4),
            QColor::fromRgb(195, 37, 3),
            QColor::fromRgb(183, 29, 2),
            QColor::fromRgb(169, 22, 1),
            QColor::fromRgb(155, 15, 1),
            QColor::fromRgb(139, 9, 2),
            QColor::fromRgb(122, 4, 3)
        };
        levels = {
            0, 5, 10, 15, 20, 26, 31, 36, 41, 46,
            51, 56, 61, 66, 71, 76, 82, 87, 92, 97,
            102, 107, 112, 117, 122, 127, 133, 138, 143, 148,
            153, 158, 163, 168, 173, 178, 184, 189, 194, 199,
            204, 209, 214, 219, 224, 229, 235, 240, 245, 250,
            255
        };

    }

    if (theme_id == LsssWhiteTheme) {
        /* experiment: TURBO */
        coloros = {
            QColor::fromRgb(255, 255, 255),
            QColor::fromRgb(239, 255, 240),
            QColor::fromRgb(59, 47, 128),
            QColor::fromRgb(63, 62, 156),
            QColor::fromRgb(66, 75, 181),
            QColor::fromRgb(69, 89, 203),
            QColor::fromRgb(70, 102, 221),
            QColor::fromRgb(71, 115, 235),
            QColor::fromRgb(70, 128, 246),
            QColor::fromRgb(68, 143, 254),
            QColor::fromRgb(62, 155, 254),
            QColor::fromRgb(55, 168, 250),
            QColor::fromRgb(46, 180, 242),
            QColor::fromRgb(37, 192, 231),
            QColor::fromRgb(30, 203, 218),
            QColor::fromRgb(25, 213, 205),
            QColor::fromRgb(24, 222, 192),
            QColor::fromRgb(29, 231, 178),
            QColor::fromRgb(39, 238, 164),
            QColor::fromRgb(53, 243, 148),
            QColor::fromRgb(70, 248, 132),
            QColor::fromRgb(89, 251, 115),
            QColor::fromRgb(109, 254, 98),
            QColor::fromRgb(128, 255, 83),
            QColor::fromRgb(146, 255, 71),
            QColor::fromRgb(164, 252, 60),
            QColor::fromRgb(177, 249, 54),
            QColor::fromRgb(190, 244, 52),
            QColor::fromRgb(203, 237, 52),
            QColor::fromRgb(215, 229, 53),
            QColor::fromRgb(225, 221, 55),
            QColor::fromRgb(235, 211, 57),
            QColor::fromRgb(242, 201, 58),
            QColor::fromRgb(248, 190, 57),
            QColor::fromRgb(252, 177, 54),
            QColor::fromRgb(254, 164, 49),
            QColor::fromRgb(254, 150, 43),
            QColor::fromRgb(252, 135, 37),
            QColor::fromRgb(249, 120, 30),
            QColor::fromRgb(245, 105, 24),
            QColor::fromRgb(240, 91, 18),
            QColor::fromRgb(234, 78, 13),
            QColor::fromRgb(225, 65, 9),
            QColor::fromRgb(216, 55, 6),
            QColor::fromRgb(206, 45, 4),
            QColor::fromRgb(195, 37, 3),
            QColor::fromRgb(183, 29, 2),
            QColor::fromRgb(169, 22, 1),
            QColor::fromRgb(155, 15, 1),
            QColor::fromRgb(139, 9, 2),
            QColor::fromRgb(122, 4, 3)
        };

        levels = {
            0, 5, 10, 15, 20, 26, 31, 36, 41, 46,
            51, 56, 61, 66, 71, 76, 82, 87, 92, 97,
            102, 107, 112, 117, 122, 127, 133, 138, 143, 148,
            153, 158, 163, 168, 173, 178, 184, 189, 194, 199,
            204, 209, 214, 219, 224, 229, 235, 240, 245, 250,
            255
        };

    } else if (theme_id == SonicBlackTheme) {

        //This is SONIC black
        coloros = {
            //QColor::fromRgb(  0,   0,   0),
            QColor::fromRgb(  0,   0,  96),
            QColor::fromRgb(  0,   0, 106),
            QColor::fromRgb(  0,   0, 116),
            QColor::fromRgb(  0,   0, 126),
            QColor::fromRgb(  0,   0, 135),
            QColor::fromRgb(  0,   0, 145),
            QColor::fromRgb(  0,   0, 155),
            QColor::fromRgb(  0,   0, 165),
            QColor::fromRgb(  0,   0, 175),
            QColor::fromRgb(  0,   0, 185),
            QColor::fromRgb(  0,   0, 194),
            QColor::fromRgb(  0,   0, 204),
            QColor::fromRgb(  0,   0, 214),
            QColor::fromRgb(  0,   0, 224),
            QColor::fromRgb(  0,  11, 213),
            QColor::fromRgb(  0,  22, 202),
            QColor::fromRgb(  0,  34, 190),
            QColor::fromRgb(  0,  45, 179),
            QColor::fromRgb(  0,  56, 168),
            QColor::fromRgb(  0,  67, 157),
            QColor::fromRgb(  0,  78, 146),
            QColor::fromRgb(  0,  90, 134),
            QColor::fromRgb(  0, 101, 123),
            QColor::fromRgb(  0, 112, 112),
            QColor::fromRgb(  0, 123, 101),
            QColor::fromRgb(  0, 134,  90),
            QColor::fromRgb(  0, 146,  78),
            QColor::fromRgb(  0, 157,  67),
            QColor::fromRgb(  0, 168,  56),
            QColor::fromRgb(  0, 179,  45),
            QColor::fromRgb(  0, 190,  34),
            QColor::fromRgb(  0, 202,  22),
            QColor::fromRgb(  0, 213,  11),
            QColor::fromRgb(  0, 224,   0),
            QColor::fromRgb( 16, 226,   0),
            QColor::fromRgb( 32, 228,   0),
            QColor::fromRgb( 48, 230,   0),
            QColor::fromRgb( 64, 232,   0),
            QColor::fromRgb( 80, 234,   0),
            QColor::fromRgb( 96, 236,   0),
            QColor::fromRgb(112, 238,   0),
            QColor::fromRgb(128, 240,   0),
            QColor::fromRgb(143, 241,   0),
            QColor::fromRgb(159, 243,   0),
            QColor::fromRgb(175, 245,   0),
            QColor::fromRgb(191, 247,   0),
            QColor::fromRgb(207, 249,   0),
            QColor::fromRgb(223, 251,   0),
            QColor::fromRgb(239, 253,   0),
            QColor::fromRgb(255, 255,   0),
            QColor::fromRgb(255, 247,   0),
            QColor::fromRgb(255, 239,   0),
            QColor::fromRgb(255, 231,   0),
            QColor::fromRgb(255, 223,   0),
            QColor::fromRgb(255, 215,   0),
            QColor::fromRgb(255, 207,   0),
            QColor::fromRgb(255, 199,   0),
            QColor::fromRgb(255, 191,   0),
            QColor::fromRgb(255, 184,   0),
            QColor::fromRgb(255, 176,   0),
            QColor::fromRgb(255, 168,   0),
            QColor::fromRgb(255, 160,   0),
            QColor::fromRgb(255, 152,   0),
            QColor::fromRgb(255, 144,   0),
            QColor::fromRgb(255, 136,   0),
            QColor::fromRgb(255, 128,   0),
            QColor::fromRgb(253, 120,   0),
            QColor::fromRgb(251, 112,   0),
            QColor::fromRgb(249, 104,   0),
            QColor::fromRgb(247,  96,   0),
            QColor::fromRgb(245,  88,   0),
            QColor::fromRgb(243,  80,   0),
            QColor::fromRgb(241,  72,   0),
            QColor::fromRgb(239,  64,   0),
            QColor::fromRgb(238,  56,   0),
            QColor::fromRgb(236,  48,   0),
            QColor::fromRgb(234,  40,   0),
            QColor::fromRgb(232,  32,   0),
            QColor::fromRgb(230,  24,   0),
            QColor::fromRgb(228,  16,   0),
            QColor::fromRgb(226,   8,   0),
            QColor::fromRgb(224,   0,   0),
            QColor::fromRgb(217,   0,   0),
            QColor::fromRgb(210,   0,   0),
            QColor::fromRgb(203,   0,   0),
            QColor::fromRgb(197,   0,   0),
            QColor::fromRgb(190,   0,   0),
            QColor::fromRgb(183,   0,   0),
            QColor::fromRgb(176,   0,   0),
            QColor::fromRgb(169,   0,   0),
            QColor::fromRgb(162,   0,   0),
            QColor::fromRgb(155,   0,   0),
            QColor::fromRgb(149,   0,   0),
            QColor::fromRgb(142,   0,   0),
            QColor::fromRgb(135,   0,   0),
            QColor::fromRgb(128,   0,   0)
        };

        levels = {
            0, 5, 8, 11, 13, 16, 19, 21, 24, 27, 29, 32, 35, 37, 40,
            43, 45, 48, 50, 53, 56, 58, 61, 64, 66, 69, 72, 74, 77, 80, 82,
            85, 88, 90, 93, 96, 98, 101, 104, 106, 109, 112, 114, 117, 120, 122, 125,
            128, 130, 133, 135, 138, 141, 143, 146, 149, 151, 154, 157, 159, 162, 165, 167,
            170, 173, 175, 178, 181, 183, 186, 189, 191, 194, 197, 199, 202, 205, 207, 210,
            213, 215, 218, 220, 223, 226, 228, 231, 234, 236, 239, 242, 244, 247, 250, 252,
            255
        };

    } else if(theme_id == SonicWhiteTheme) {

        //This is SONIC white
        coloros = {
            QColor::fromRgb(255, 255, 255),
            QColor::fromRgb(  0,   0,  96),
            QColor::fromRgb(  0,   0, 106),
            QColor::fromRgb(  0,   0, 116),
            QColor::fromRgb(  0,   0, 126),
            QColor::fromRgb(  0,   0, 135),
            QColor::fromRgb(  0,   0, 145),
            QColor::fromRgb(  0,   0, 155),
            QColor::fromRgb(  0,   0, 165),
            QColor::fromRgb(  0,   0, 175),
            QColor::fromRgb(  0,   0, 185),
            QColor::fromRgb(  0,   0, 194),
            QColor::fromRgb(  0,   0, 204),
            QColor::fromRgb(  0,   0, 214),
            QColor::fromRgb(  0,   0, 224),
            QColor::fromRgb(  0,  11, 213),
            QColor::fromRgb(  0,  22, 202),
            QColor::fromRgb(  0,  34, 190),
            QColor::fromRgb(  0,  45, 179),
            QColor::fromRgb(  0,  56, 168),
            QColor::fromRgb(  0,  67, 157),
            QColor::fromRgb(  0,  78, 146),
            QColor::fromRgb(  0,  90, 134),
            QColor::fromRgb(  0, 101, 123),
            QColor::fromRgb(  0, 112, 112),
            QColor::fromRgb(  0, 123, 101),
            QColor::fromRgb(  0, 134,  90),
            QColor::fromRgb(  0, 146,  78),
            QColor::fromRgb(  0, 157,  67),
            QColor::fromRgb(  0, 168,  56),
            QColor::fromRgb(  0, 179,  45),
            QColor::fromRgb(  0, 190,  34),
            QColor::fromRgb(  0, 202,  22),
            QColor::fromRgb(  0, 213,  11),
            QColor::fromRgb(  0, 224,   0),
            QColor::fromRgb( 16, 226,   0),
            QColor::fromRgb( 32, 228,   0),
            QColor::fromRgb( 48, 230,   0),
            QColor::fromRgb( 64, 232,   0),
            QColor::fromRgb( 80, 234,   0),
            QColor::fromRgb( 96, 236,   0),
            QColor::fromRgb(112, 238,   0),
            QColor::fromRgb(128, 240,   0),
            QColor::fromRgb(143, 241,   0),
            QColor::fromRgb(159, 243,   0),
            QColor::fromRgb(175, 245,   0),
            QColor::fromRgb(191, 247,   0),
            QColor::fromRgb(207, 249,   0),
            QColor::fromRgb(223, 251,   0),
            QColor::fromRgb(239, 253,   0),
            QColor::fromRgb(255, 255,   0),
            QColor::fromRgb(255, 247,   0),
            QColor::fromRgb(255, 239,   0),
            QColor::fromRgb(255, 231,   0),
            QColor::fromRgb(255, 223,   0),
            QColor::fromRgb(255, 215,   0),
            QColor::fromRgb(255, 207,   0),
            QColor::fromRgb(255, 199,   0),
            QColor::fromRgb(255, 191,   0),
            QColor::fromRgb(255, 184,   0),
            QColor::fromRgb(255, 176,   0),
            QColor::fromRgb(255, 168,   0),
            QColor::fromRgb(255, 160,   0),
            QColor::fromRgb(255, 152,   0),
            QColor::fromRgb(255, 144,   0),
            QColor::fromRgb(255, 136,   0),
            QColor::fromRgb(255, 128,   0),
            QColor::fromRgb(253, 120,   0),
            QColor::fromRgb(251, 112,   0),
            QColor::fromRgb(249, 104,   0),
            QColor::fromRgb(247,  96,   0),
            QColor::fromRgb(245,  88,   0),
            QColor::fromRgb(243,  80,   0),
            QColor::fromRgb(241,  72,   0),
            QColor::fromRgb(239,  64,   0),
            QColor::fromRgb(238,  56,   0),
            QColor::fromRgb(236,  48,   0),
            QColor::fromRgb(234,  40,   0),
            QColor::fromRgb(232,  32,   0),
            QColor::fromRgb(230,  24,   0),
            QColor::fromRgb(228,  16,   0),
            QColor::fromRgb(226,   8,   0),
            QColor::fromRgb(224,   0,   0),
            QColor::fromRgb(217,   0,   0),
            QColor::fromRgb(210,   0,   0),
            QColor::fromRgb(203,   0,   0),
            QColor::fromRgb(197,   0,   0),
            QColor::fromRgb(190,   0,   0),
            QColor::fromRgb(183,   0,   0),
            QColor::fromRgb(176,   0,   0),
            QColor::fromRgb(169,   0,   0),
            QColor::fromRgb(162,   0,   0),
            QColor::fromRgb(155,   0,   0),
            QColor::fromRgb(149,   0,   0),
            QColor::fromRgb(142,   0,   0),
            QColor::fromRgb(135,   0,   0),
            QColor::fromRgb(128,   0,   0)
        };


        levels = {
            0, 3, 5, 8, 11, 13, 16, 19, 21, 24, 27, 29, 32, 35, 37, 40,
            43, 45, 48, 50, 53, 56, 58, 61, 64, 66, 69, 72, 74, 77, 80, 82,
            85, 88, 90, 93, 96, 98, 101, 104, 106, 109, 112, 114, 117, 120, 122, 125,
            128, 130, 133, 135, 138, 141, 143, 146, 149, 151, 154, 157, 159, 162, 165, 167,
            170, 173, 175, 178, 181, 183, 186, 189, 191, 194, 197, 199, 202, 205, 207, 210,
            213, 215, 218, 220, 223, 226, 228, 231, 234, 236, 239, 242, 244, 247, 250, 252,
            255
        };

    } else if (theme_id == SepiaTemeExtra) {

        coloros = {
           QColor("#000000"),
           QColor("#19120d"),
           QColor("#2a1d16"),
           QColor("#3c281c"),
           QColor("#4f3423"),
           QColor("#62402a"),
           QColor("#764c32"),
           QColor("#8b5939"),
           QColor("#a16641"),
           QColor("#b77348"),
           QColor("#cd8050"),
           QColor("#e48e58")};

        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };

    }

    else if (theme_id == PulseTheme_bluered) {
        coloros = {

        // Our own palette - from blue to red
        QColor::fromRgb(  0,   0, 255),
            QColor::fromRgb(  0,  32, 255),
            QColor::fromRgb(  0,  64, 255),
            QColor::fromRgb(  0,  96, 255),
            QColor::fromRgb(  0, 128, 255),
            QColor::fromRgb(  0, 159, 255),
            QColor::fromRgb(  0, 191, 255),
            QColor::fromRgb(  0, 223, 255),
            QColor::fromRgb(  0, 255, 255),
            QColor::fromRgb( 42, 255, 211),
            QColor::fromRgb( 84, 255, 167),
            QColor::fromRgb(125, 255, 123),
            QColor::fromRgb(167, 255,  79),
            QColor::fromRgb(182, 255,  66),
            QColor::fromRgb(196, 255,  53),
            QColor::fromRgb(211, 255,  39),
            QColor::fromRgb(226, 255,  26),
            QColor::fromRgb(240, 255,  13),
            QColor::fromRgb(255, 255,   0),
            QColor::fromRgb(255, 219,   0),
            QColor::fromRgb(255, 182,   0),
            QColor::fromRgb(255, 146,   0),
            QColor::fromRgb(255, 109,   0),
            QColor::fromRgb(255,  73,   0),
            QColor::fromRgb(255,  36,   0),
            QColor::fromRgb(255,   0,   0)
    };

    // 26 levels evenly spaced from 0 to 255 (step ≃ 255/25 ≃ 10.2, rounded)
    levels = {
        0,  10,  20,  31,  41,  51,  61,  71,
        82,  92, 102, 112, 122, 133, 143, 153,
        163, 173, 184, 194, 204, 214, 224, 235,
        245, 255
    };
}

    else if (theme_id == PulseTheme_rainbow) {

        coloros = {
           QColor::fromRgb(128, 0, 255),
           QColor::fromRgb(116, 19, 255),
           QColor::fromRgb(102, 41, 254),
           QColor::fromRgb(90, 59, 253),
           QColor::fromRgb(76, 80, 252),
           QColor::fromRgb(64, 98, 250),
           QColor::fromRgb(49, 118, 248),
           QColor::fromRgb(38, 134, 245),
           QColor::fromRgb(24, 152, 242),
           QColor::fromRgb(9, 169, 238),
           QColor::fromRgb(2, 183, 235),
           QColor::fromRgb(16, 198, 230),
           QColor::fromRgb(29, 209, 226),
           QColor::fromRgb(42, 221, 221),
           QColor::fromRgb(55, 230, 216),
           QColor::fromRgb(68, 238, 210),
           QColor::fromRgb(82, 245, 203),
           QColor::fromRgb(94, 250, 198),
           QColor::fromRgb(109, 253, 191),
           QColor::fromRgb(120, 255, 184),
           QColor::fromRgb(134, 255, 176),
           QColor::fromRgb(146, 253, 169),
           QColor::fromRgb(160, 250, 161),
           QColor::fromRgb(172, 245, 154),
           QColor::fromRgb(187, 238, 145),
           QColor::fromRgb(200, 230, 136),
           QColor::fromRgb(212, 221, 128),
           QColor::fromRgb(226, 209, 118),
           QColor::fromRgb(238, 198, 109),
           QColor::fromRgb(252, 183, 99),
           QColor::fromRgb(255, 169, 91),
           QColor::fromRgb(255, 152, 80),
           QColor::fromRgb(255, 134, 70),
           QColor::fromRgb(255, 118, 61),
           QColor::fromRgb(255, 98, 50),
           QColor::fromRgb(255, 80, 41),
           QColor::fromRgb(255, 59, 30),
           QColor::fromRgb(255, 41, 20),
           QColor::fromRgb(255, 19, 9),
           QColor::fromRgb(255, 0, 0)};

        levels = {
              0, 7, 13, 20, 26, 33, 39, 46, 52, 59,
              65, 72, 78, 85, 92, 98, 105, 111, 118, 124,
              131, 137, 144, 150, 157, 163, 170, 177, 183, 190,
              196, 203, 209, 216, 222, 229, 235, 242, 248, 255
        };

    }

    else if (theme_id == HQthemeOrange) {
        coloros = {
            QColor::fromRgb(0,0,0),
            QColor::fromRgb(1,0,0),
            QColor::fromRgb(1,1,0),
            QColor::fromRgb(2,1,0),
            QColor::fromRgb(2,1,0),
            QColor::fromRgb(3,1,0),
            QColor::fromRgb(4,2,0),
            QColor::fromRgb(4,2,0),
            QColor::fromRgb(5,2,0),
            QColor::fromRgb(6,3,0),
            QColor::fromRgb(6,3,0),
            QColor::fromRgb(7,3,0),
            QColor::fromRgb(8,3,0),
            QColor::fromRgb(8,4,0),
            QColor::fromRgb(9,4,0),
            QColor::fromRgb(9,4,0),
            QColor::fromRgb(10,4,0),
            QColor::fromRgb(11,5,0),
            QColor::fromRgb(11,5,0),
            QColor::fromRgb(12,5,0),
            QColor::fromRgb(12,6,0),
            QColor::fromRgb(13,6,0),
            QColor::fromRgb(14,6,0),
            QColor::fromRgb(14,6,0),
            QColor::fromRgb(15,7,0),
            QColor::fromRgb(16,7,0),
            QColor::fromRgb(16,7,0),
            QColor::fromRgb(17,8,0),
            QColor::fromRgb(18,8,0),
            QColor::fromRgb(18,8,0),
            QColor::fromRgb(19,8,0),
            QColor::fromRgb(19,9,0),
            QColor::fromRgb(20,9,0),
            QColor::fromRgb(21,9,0),
            QColor::fromRgb(21,10,0),
            QColor::fromRgb(22,10,0),
            QColor::fromRgb(22,10,0),
            QColor::fromRgb(23,10,0),
            QColor::fromRgb(24,11,0),
            QColor::fromRgb(24,11,0),
            QColor::fromRgb(25,11,0),
            QColor::fromRgb(26,12,0),
            QColor::fromRgb(26,12,0),
            QColor::fromRgb(27,12,0),
            QColor::fromRgb(28,12,0),
            QColor::fromRgb(28,13,0),
            QColor::fromRgb(29,13,0),
            QColor::fromRgb(29,13,0),
            QColor::fromRgb(30,14,0),
            QColor::fromRgb(31,14,0),
            QColor::fromRgb(31,14,0),
            QColor::fromRgb(32,14,0),
            QColor::fromRgb(32,15,0),
            QColor::fromRgb(33,15,0),
            QColor::fromRgb(34,15,0),
            QColor::fromRgb(34,15,0),
            QColor::fromRgb(35,16,0),
            QColor::fromRgb(36,16,0),
            QColor::fromRgb(36,16,0),
            QColor::fromRgb(37,17,0),
            QColor::fromRgb(38,17,0),
            QColor::fromRgb(38,17,0),
            QColor::fromRgb(39,17,0),
            QColor::fromRgb(39,18,0),
            QColor::fromRgb(40,18,0),
            QColor::fromRgb(42,19,0),
            QColor::fromRgb(44,21,0),
            QColor::fromRgb(47,22,0),
            QColor::fromRgb(49,23,0),
            QColor::fromRgb(51,24,0),
            QColor::fromRgb(53,26,0),
            QColor::fromRgb(56,27,0),
            QColor::fromRgb(58,28,0),
            QColor::fromRgb(60,29,0),
            QColor::fromRgb(62,31,0),
            QColor::fromRgb(65,32,0),
            QColor::fromRgb(67,33,0),
            QColor::fromRgb(69,35,0),
            QColor::fromRgb(71,36,0),
            QColor::fromRgb(74,37,0),
            QColor::fromRgb(76,38,0),
            QColor::fromRgb(78,40,0),
            QColor::fromRgb(80,41,0),
            QColor::fromRgb(83,42,0),
            QColor::fromRgb(85,43,0),
            QColor::fromRgb(87,45,0),
            QColor::fromRgb(89,46,0),
            QColor::fromRgb(92,47,0),
            QColor::fromRgb(94,48,0),
            QColor::fromRgb(96,50,0),
            QColor::fromRgb(98,51,0),
            QColor::fromRgb(100,52,0),
            QColor::fromRgb(103,54,0),
            QColor::fromRgb(105,55,0),
            QColor::fromRgb(107,56,0),
            QColor::fromRgb(109,57,0),
            QColor::fromRgb(112,59,0),
            QColor::fromRgb(114,60,0),
            QColor::fromRgb(116,61,0),
            QColor::fromRgb(118,62,0),
            QColor::fromRgb(121,64,0),
            QColor::fromRgb(123,65,0),
            QColor::fromRgb(125,66,0),
            QColor::fromRgb(127,68,0),
            QColor::fromRgb(130,69,0),
            QColor::fromRgb(132,70,0),
            QColor::fromRgb(134,71,0),
            QColor::fromRgb(136,73,0),
            QColor::fromRgb(139,74,0),
            QColor::fromRgb(141,75,0),
            QColor::fromRgb(143,76,0),
            QColor::fromRgb(145,78,0),
            QColor::fromRgb(148,79,0),
            QColor::fromRgb(150,80,0),
            QColor::fromRgb(152,82,0),
            QColor::fromRgb(154,83,0),
            QColor::fromRgb(156,84,0),
            QColor::fromRgb(159,85,0),
            QColor::fromRgb(161,87,0),
            QColor::fromRgb(163,88,0),
            QColor::fromRgb(165,89,0),
            QColor::fromRgb(168,90,0),
            QColor::fromRgb(170,92,0),
            QColor::fromRgb(172,93,0),
            QColor::fromRgb(174,94,0),
            QColor::fromRgb(177,96,0),
            QColor::fromRgb(179,97,0),
            QColor::fromRgb(181,98,0),
            QColor::fromRgb(183,99,0),
            QColor::fromRgb(186,101,0),
            QColor::fromRgb(188,102,0),
            QColor::fromRgb(190,103,0),
            QColor::fromRgb(192,104,0),
            QColor::fromRgb(195,106,0),
            QColor::fromRgb(197,107,0),
            QColor::fromRgb(199,108,0),
            QColor::fromRgb(201,110,0),
            QColor::fromRgb(203,111,0),
            QColor::fromRgb(206,112,0),
            QColor::fromRgb(208,113,0),
            QColor::fromRgb(210,115,0),
            QColor::fromRgb(212,116,0),
            QColor::fromRgb(215,117,0),
            QColor::fromRgb(217,118,0),
            QColor::fromRgb(219,120,0),
            QColor::fromRgb(221,121,0),
            QColor::fromRgb(224,122,0),
            QColor::fromRgb(226,123,0),
            QColor::fromRgb(228,125,0),
            QColor::fromRgb(230,126,0),
            QColor::fromRgb(233,127,0),
            QColor::fromRgb(235,129,0),
            QColor::fromRgb(237,130,0),
            QColor::fromRgb(239,131,0),
            QColor::fromRgb(242,132,0),
            QColor::fromRgb(244,134,0),
            QColor::fromRgb(246,135,0),
            QColor::fromRgb(248,136,0),
            QColor::fromRgb(251,137,0),
            QColor::fromRgb(253,139,0),
            QColor::fromRgb(255,140,0),
            QColor::fromRgb(255,141,2),
            QColor::fromRgb(255,142,4),
            QColor::fromRgb(255,143,6),
            QColor::fromRgb(255,144,8),
            QColor::fromRgb(255,146,11),
            QColor::fromRgb(255,147,13),
            QColor::fromRgb(255,148,15),
            QColor::fromRgb(255,149,17),
            QColor::fromRgb(255,150,19),
            QColor::fromRgb(255,151,21),
            QColor::fromRgb(255,152,23),
            QColor::fromRgb(255,153,25),
            QColor::fromRgb(255,154,27),
            QColor::fromRgb(255,155,29),
            QColor::fromRgb(255,157,32),
            QColor::fromRgb(255,158,34),
            QColor::fromRgb(255,159,36),
            QColor::fromRgb(255,160,38),
            QColor::fromRgb(255,161,40),
            QColor::fromRgb(255,162,42),
            QColor::fromRgb(255,163,44),
            QColor::fromRgb(255,164,46),
            QColor::fromRgb(255,165,48),
            QColor::fromRgb(255,167,51),
            QColor::fromRgb(255,168,53),
            QColor::fromRgb(255,169,55),
            QColor::fromRgb(255,170,57),
            QColor::fromRgb(255,171,59),
            QColor::fromRgb(255,172,61),
            QColor::fromRgb(255,173,63),
            QColor::fromRgb(255,174,65),
            QColor::fromRgb(255,175,67),
            QColor::fromRgb(255,176,69),
            QColor::fromRgb(255,178,72),
            QColor::fromRgb(255,179,74),
            QColor::fromRgb(255,180,76),
            QColor::fromRgb(255,181,78),
            QColor::fromRgb(255,182,80),
            QColor::fromRgb(255,183,82),
            QColor::fromRgb(255,184,84),
            QColor::fromRgb(255,185,86),
            QColor::fromRgb(255,186,88),
            QColor::fromRgb(255,188,91),
            QColor::fromRgb(255,189,93),
            QColor::fromRgb(255,190,95),
            QColor::fromRgb(255,191,97),
            QColor::fromRgb(255,192,99),
            QColor::fromRgb(255,193,101),
            QColor::fromRgb(255,194,103),
            QColor::fromRgb(255,195,105),
            QColor::fromRgb(255,196,107),
            QColor::fromRgb(255,197,109),
            QColor::fromRgb(255,199,112),
            QColor::fromRgb(255,200,114),
            QColor::fromRgb(255,201,116),
            QColor::fromRgb(255,202,118),
            QColor::fromRgb(255,203,120),
            QColor::fromRgb(255,204,122),
            QColor::fromRgb(255,205,124),
            QColor::fromRgb(255,206,126),
            QColor::fromRgb(255,207,128),
            QColor::fromRgb(255,209,131),
            QColor::fromRgb(255,210,133),
            QColor::fromRgb(255,211,135),
            QColor::fromRgb(255,212,137),
            QColor::fromRgb(255,213,139),
            QColor::fromRgb(255,214,141),
            QColor::fromRgb(255,215,143),
            QColor::fromRgb(255,216,145),
            QColor::fromRgb(255,217,147),
            QColor::fromRgb(255,218,149),
            QColor::fromRgb(255,220,152),
            QColor::fromRgb(255,221,154),
            QColor::fromRgb(255,222,156),
            QColor::fromRgb(255,223,158),
            QColor::fromRgb(255,224,160),
            QColor::fromRgb(255,225,162),
            QColor::fromRgb(255,226,164),
            QColor::fromRgb(255,227,166),
            QColor::fromRgb(255,228,168),
            QColor::fromRgb(255,230,171),
            QColor::fromRgb(255,231,173),
            QColor::fromRgb(255,232,175),
            QColor::fromRgb(255,233,177),
            QColor::fromRgb(255,234,179),
            QColor::fromRgb(255,235,181),
            QColor::fromRgb(255,236,183),
            QColor::fromRgb(255,237,185),
            QColor::fromRgb(255,238,187),
            QColor::fromRgb(255,239,189),
            QColor::fromRgb(255,241,192),
            QColor::fromRgb(255,242,194),
            QColor::fromRgb(255,243,196),
            QColor::fromRgb(255,244,198),
            QColor::fromRgb(255,245,200)
    };

    // 256 levels evenly spaced from 0 to 255
        levels.resize(256);
        std::iota(levels.begin(), levels.end(), 0);
    } else if(theme_id == HQthemePurple) {

        coloros = {
                   QColor("#000000"),
                   QColor("#000001"),
                   QColor("#000001"),
                   QColor("#010002"),
                   QColor("#010002"),
                   QColor("#010003"),
                   QColor("#020003"),
                   QColor("#020004"),
                   QColor("#020004"),
                   QColor("#020005"),
                   QColor("#020006"),
                   QColor("#030006"),
                   QColor("#030007"),
                   QColor("#030007"),
                   QColor("#040008"),
                   QColor("#040008"),
                   QColor("#040009"),
                   QColor("#04000A"),
                   QColor("#04000A"),
                   QColor("#05000B"),
                   QColor("#05000B"),
                   QColor("#05000C"),
                   QColor("#06000C"),
                   QColor("#06000D"),
                   QColor("#06000E"),
                   QColor("#06000E"),
                   QColor("#06000F"),
                   QColor("#07000F"),
                   QColor("#070010"),
                   QColor("#070010"),
                   QColor("#080011"),
                   QColor("#080011"),
                   QColor("#080012"),
                   QColor("#090013"),
                   QColor("#090015"),
                   QColor("#0A0016"),
                   QColor("#0A0017"),
                   QColor("#0B0018"),
                   QColor("#0C001A"),
                   QColor("#0C001B"),
                   QColor("#0D001C"),
                   QColor("#0E001E"),
                   QColor("#0E001F"),
                   QColor("#0F0020"),
                   QColor("#100021"),
                   QColor("#100023"),
                   QColor("#110024"),
                   QColor("#110025"),
                   QColor("#120026"),
                   QColor("#130028"),
                   QColor("#130029"),
                   QColor("#14002A"),
                   QColor("#14002C"),
                   QColor("#15002D"),
                   QColor("#16002E"),
                   QColor("#16002F"),
                   QColor("#170031"),
                   QColor("#180032"),
                   QColor("#180033"),
                   QColor("#190035"),
                   QColor("#1A0036"),
                   QColor("#1A0037"),
                   QColor("#1B0038"),
                   QColor("#1B003A"),
                   QColor("#1C003B"),
                   QColor("#1D003C"),
                   QColor("#1E003E"),
                   QColor("#1F003F"),
                   QColor("#1F0041"),
                   QColor("#200042"),
                   QColor("#210044"),
                   QColor("#220045"),
                   QColor("#230047"),
                   QColor("#240048"),
                   QColor("#24004A"),
                   QColor("#25004B"),
                   QColor("#26004D"),
                   QColor("#27004E"),
                   QColor("#280050"),
                   QColor("#290051"),
                   QColor("#2A0052"),
                   QColor("#2A0054"),
                   QColor("#2B0055"),
                   QColor("#2C0057"),
                   QColor("#2D0058"),
                   QColor("#2E005A"),
                   QColor("#2F005B"),
                   QColor("#2F005D"),
                   QColor("#30005E"),
                   QColor("#310060"),
                   QColor("#320061"),
                   QColor("#330063"),
                   QColor("#340064"),
                   QColor("#340066"),
                   QColor("#350067"),
                   QColor("#360069"),
                   QColor("#37006A"),
                   QColor("#38006C"),
                   QColor("#39006D"),
                   QColor("#3B006E"),
                   QColor("#3C0070"),
                   QColor("#3D0072"),
                   QColor("#3E0073"),
                   QColor("#400074"),
                   QColor("#410076"),
                   QColor("#420078"),
                   QColor("#430079"),
                   QColor("#44007A"),
                   QColor("#46007C"),
                   QColor("#47007E"),
                   QColor("#48007F"),
                   QColor("#490080"),
                   QColor("#4A0082"),
                   QColor("#4C0084"),
                   QColor("#4D0085"),
                   QColor("#4E0086"),
                   QColor("#4F0088"),
                   QColor("#51008A"),
                   QColor("#52008B"),
                   QColor("#53008C"),
                   QColor("#54008E"),
                   QColor("#550090"),
                   QColor("#570091"),
                   QColor("#580092"),
                   QColor("#590094"),
                   QColor("#5A0096"),
                   QColor("#5C0097"),
                   QColor("#5D0098"),
                   QColor("#5E009A"),
                   QColor("#5F019B"),
                   QColor("#61019C"),
                   QColor("#62029E"),
                   QColor("#64029F"),
                   QColor("#6503A0"),
                   QColor("#6704A1"),
                   QColor("#6804A3"),
                   QColor("#6A05A4"),
                   QColor("#6B06A5"),
                   QColor("#6C06A6"),
                   QColor("#6E07A7"),
                   QColor("#6F08A9"),
                   QColor("#7108AA"),
                   QColor("#7209AB"),
                   QColor("#7409AC"),
                   QColor("#750AAE"),
                   QColor("#760BAF"),
                   QColor("#780BB0"),
                   QColor("#790CB1"),
                   QColor("#7B0CB2"),
                   QColor("#7C0DB4"),
                   QColor("#7E0EB5"),
                   QColor("#7F0EB6"),
                   QColor("#800FB7"),
                   QColor("#8210B8"),
                   QColor("#8310BA"),
                   QColor("#8511BB"),
                   QColor("#8612BC"),
                   QColor("#8812BD"),
                   QColor("#8913BF"),
                   QColor("#8B13C0"),
                   QColor("#8C14C1"),
                   QColor("#8D16C2"),
                   QColor("#8F18C3"),
                   QColor("#9019C4"),
                   QColor("#911BC6"),
                   QColor("#931DC7"),
                   QColor("#941FC8"),
                   QColor("#9520C9"),
                   QColor("#9722CA"),
                   QColor("#9824CB"),
                   QColor("#9926CD"),
                   QColor("#9B28CE"),
                   QColor("#9C29CF"),
                   QColor("#9D2BD0"),
                   QColor("#9F2DD1"),
                   QColor("#A02FD2"),
                   QColor("#A230D4"),
                   QColor("#A332D5"),
                   QColor("#A434D6"),
                   QColor("#A636D7"),
                   QColor("#A738D8"),
                   QColor("#A839D9"),
                   QColor("#AA3BDA"),
                   QColor("#AB3DDC"),
                   QColor("#AC3FDD"),
                   QColor("#AE41DE"),
                   QColor("#AF42DF"),
                   QColor("#B044E0"),
                   QColor("#B246E1"),
                   QColor("#B348E3"),
                   QColor("#B449E4"),
                   QColor("#B64BE5"),
                   QColor("#B74DE6"),
                   QColor("#B84EE7"),
                   QColor("#B950E8"),
                   QColor("#B951E8"),
                   QColor("#BA52E9"),
                   QColor("#BB54EA"),
                   QColor("#BC55EB"),
                   QColor("#BC56EB"),
                   QColor("#BD58EC"),
                   QColor("#BE59ED"),
                   QColor("#BF5AEE"),
                   QColor("#C05CEF"),
                   QColor("#C05DEF"),
                   QColor("#C15EF0"),
                   QColor("#C260F1"),
                   QColor("#C361F2"),
                   QColor("#C462F2"),
                   QColor("#C464F3"),
                   QColor("#C565F4"),
                   QColor("#C667F5"),
                   QColor("#C768F6"),
                   QColor("#C769F6"),
                   QColor("#C86BF7"),
                   QColor("#C96CF8"),
                   QColor("#CA6DF9"),
                   QColor("#CB6FFA"),
                   QColor("#CB70FA"),
                   QColor("#CC71FB"),
                   QColor("#CD73FC"),
                   QColor("#CE74FD"),
                   QColor("#CE75FD"),
                   QColor("#CF77FE"),
                   QColor("#D078FF"),
                   QColor("#D177FF"),
                   QColor("#D176FF"),
                   QColor("#D276FF"),
                   QColor("#D275FF"),
                   QColor("#D374FF"),
                   QColor("#D373FF"),
                   QColor("#D473FF"),
                   QColor("#D472FF"),
                   QColor("#D571FF"),
                   QColor("#D570FF"),
                   QColor("#D66FFF"),
                   QColor("#D66FFF"),
                   QColor("#D76EFF"),
                   QColor("#D76DFF"),
                   QColor("#D86CFF"),
                   QColor("#D86CFF"),
                   QColor("#D96BFF"),
                   QColor("#D96AFF"),
                   QColor("#DA69FF"),
                   QColor("#DA69FF"),
                   QColor("#DB68FF"),
                   QColor("#DB67FF"),
                   QColor("#DC66FF"),
                   QColor("#DC65FF"),
                   QColor("#DD65FF"),
                   QColor("#DD64FF"),
                   QColor("#DE63FF"),
                   QColor("#DE62FF"),
                   QColor("#DF62FF"),
                   QColor("#DF61FF"),
                   QColor("#E060FF")};

        // 256 levels evenly spaced from 0 to 255
        levels.resize(256);
        std::iota(levels.begin(), levels.end(), 0);

    }

    _rawThemeColors = coloros;
    qDebug() << "Theme ID was set by user, new ID is " << theme_id;
    qDebug() << "setThemeId called on instance:" << this;
    qDebug() << "Theme ID include colors " << _rawThemeColors;

    setColorScheme(coloros, levels);
    getThemeColors();
    publishThemeColors();
    //emit themeColorsChanged();
}


void Plot2DEchogram::setCompensation(int compensation_id)
{
    _compensation_id = compensation_id;
}

int Plot2DEchogram::getCompensation() const
{
    return _compensation_id;
}

void Plot2DEchogram::setWrapEnabled(bool state)
{
    if (wrapEnabled_ == state) {
        return;
    }

    wrapEnabled_ = state;
    resetCash();
}

void Plot2DEchogram::updateColors() {
    // 1) compute your user-range → [0..255]
    float low    = _levels.low;
    float high   = _levels.high;
    float span   = (high - low)*2.55f;
    float offset = low   *2.55f;
    float scale  = (span>0.0f ? 255.0f/span : 0.0f);

    _colorLevels.resize(256);

    // 2) how many discrete steps you really have
    const int M = _rawThemeColors.size();       // e.g. 13 or 17
    const int maxI = M - 1;

    for(int i = 0; i < 256; ++i) {
        // map into 0..255 user-window
        int raw = int(qBound(0.0f, (i - offset)*scale, 255.0f));

        // pure integer round-to-nearest across M slots
        int idx = (raw * maxI + 127) / 255;     // [0..maxI]

        // pick your exact theme color—no t, no blend
        QColor c = _rawThemeColors[idx];
        _colorLevels[i] = qRgb(c.red(), c.green(), c.blue());
    }

    _flagColorChanged = true;
    _image.setColorTable(_colorLevels);
}


void Plot2DEchogram::resetCash()
{
    _cashFlags.resetCash = true;
}

void Plot2DEchogram::addReRenderPlotIndxs(const QSet<int> &indxs)
{
    reRenderPlotIndxs_.unite(indxs);
}

int Plot2DEchogram::updateCash(Plot2D* parent, Dataset* dataset, int width, int height)
{
    auto& cursor = parent->cursor();

    if (_cash.size() != width) {
        _cash.resize(width);
        resetCash();
    }

    uint8_t* image_data = _image.bits();
    const int b_scanline = _image.bytesPerLine();

    bool is_cash_notvalid = getTriggerCashReset();
    is_cash_notvalid |= !_lastCursor.isChannelsEqual(cursor);
    is_cash_notvalid |= !_lastCursor.isDistanceEqual(cursor);
    is_cash_notvalid |=  _lastWidth != width;
    is_cash_notvalid |=  _lastHeight != height;


    float from = cursor.distance.from;
    float to = cursor.distance.to;
    float fullrange = to - from;

    float range1 = 0;
    float from1 = 0;
    float to1 = 0;

    float from2 = 0;
    float to2 = 0;

    if (to >= 0) {
        range1 = 0 - from;
        from1 = 0;
        to1 = -from;

        if (from >= 0) {
            from2 = from;
        }
        else {
            from2 = 0;
        }
        to2 = to;
    }
    else {
        range1 = to - from;
        from1 = -to;
        to1 = -from;
    }


//    _cashPosition = wrap_start_pos;
    for(int column = 0; column < width; column++) {
        if(_cash[column].data.size() != height) {
//            _cash[column].stateColor = CashLine::CashState::CashStateNotValid;
            _cash[column].state = CashLine::CashState::CashStateNotValid;
            _cash[column].data.resize(height);
            _cash[column].data.fill(0); //TODO: Does this help remove the side scan remaining artifact?
            _cash[column].poolIndex = -1;
            _cash[column].state = CashLine::CashState::CashStateEraced;
            _cash[column].isNeedUpdate = true;

            int16_t cash_data_size = _cash[column].data.size();
            int16_t* cash_data = _cash[column].data.data();
            uint8_t * img_data = image_data + column;
            for (int image_row = 0; image_row < cash_data_size; image_row++) {
                *img_data = *cash_data;
                img_data += b_scanline;
                cash_data++;
            }
        }

        const int pool_index = (column >= 0 && column < (int)cursor.indexes.size())
                                   ? cursor.indexes[column]
                                   : -1;
        const int pool_index_safe = dataset->validIndex(pool_index);

        //int pool_index = cursor.getIndex(cursor_pos);
        //int pool_index_safe = dataset->validIndex(pool_index);
        if(pool_index_safe >= 0) {

            bool wasValidlyRendered = true;
            if (reRenderPlotIndxs_.contains(pool_index_safe)) {
                reRenderPlotIndxs_.remove(pool_index_safe);
                wasValidlyRendered = false;
            }

            auto* datasource = dataset->fromIndex(pool_index_safe);
            const int cash_index = _cash[column].poolIndex;

            if (is_cash_notvalid || pool_index_safe != cash_index || !wasValidlyRendered) {
                _cash[column].poolIndex = pool_index_safe;

                if(datasource != NULL) {
                    _cash[column].state = CashLine::CashState::CashStateNotValid;
                    int16_t* cash_data = _cash[column].data.data();
                    int16_t cash_data_size = _cash[column].data.size();

                    if (cursor.channel2 == CHANNEL_NONE) {
                        datasource->chartTo(cursor.channel1, cursor.subChannel1, from, to, cash_data, cash_data_size, _compensation_id);
                    }
                    else {
                        int cash_data_size_part1 = cash_data_size*(range1/fullrange);

                        if(cash_data_size_part1 > 0) {
                            datasource->chartTo(cursor.channel1, cursor.subChannel1, from1, to1, cash_data, cash_data_size_part1, _compensation_id, true);
                        }

                        if(cash_data_size_part1 < 0) {
                            cash_data_size_part1 = 0;
                        }

                        const int cash_data_size_part2 = cash_data_size - cash_data_size_part1;
                        if(cash_data_size_part2 > 0) {
                            datasource->chartTo(cursor.channel2, cursor.subChannel2, from2, to2, &cash_data[cash_data_size_part1], cash_data_size_part2, _compensation_id, false);
                        }
                    }

                    _cash[column].state = CashLine::CashState::CashStateValid;
                    _cash[column].isNeedUpdate = true;
                    uint8_t * img_data = image_data + column;
                    for (int image_row = 0; image_row < cash_data_size; image_row++) {
                        *img_data = *cash_data;
                        img_data += b_scanline;
                        cash_data++;
                    }
//                    _cash[column].stateColor = CashLine::CashState::CashStateNotValid;
                } else {
                    if(is_cash_notvalid || _cash[column].state != CashLine::CashState::CashStateEraced) {
//                        _cash[column].stateColor = CashLine::CashState::CashStateNotValid;
                        _cash[column].state = CashLine::CashState::CashStateNotValid;
                        _cash[column].data.fill(0);
                        _cash[column].poolIndex = -1;
                        _cash[column].state = CashLine::CashState::CashStateEraced;
                        _cash[column].isNeedUpdate = true;

                        int16_t cash_data_size = _cash[column].data.size();
                        int16_t* cash_data = _cash[column].data.data();
                        uint8_t * img_data = image_data + column;
                        for (int image_row = 0; image_row < cash_data_size; image_row++) {
                            *img_data = *cash_data;
                            img_data += b_scanline;
                            cash_data++;
                        }
                    }
                }

            }
        } else {
            if(is_cash_notvalid || _cash[column].state != CashLine::CashState::CashStateEraced) {
//                _cash[column].stateColor = CashLine::CashState::CashStateNotValid;
                _cash[column].state = CashLine::CashState::CashStateNotValid;
                _cash[column].data.fill(0);
                _cash[column].poolIndex = -1;
                _cash[column].state = CashLine::CashState::CashStateEraced;
                _cash[column].isNeedUpdate = true;

                int16_t* cash_data = _cash[column].data.data();
                int16_t cash_data_size = _cash[column].data.size();
                uint8_t * img_data = image_data + column;
                for (int image_row = 0; image_row < cash_data_size; image_row++) {
                    *img_data = *cash_data;
                    img_data += b_scanline;
                    cash_data++;
                }
            }

        }
    }

    //qInfo("Cash validate %u", cash_validate);

    _lastCursor = cursor;
    _lastWidth = width;
    _lastHeight = height;

    return 0;
    //return wrap_start_pos;
}

bool Plot2DEchogram::draw(Plot2D* parent, Dataset* dataset)
{
    auto& canvas = parent->canvas();
    auto& cursor = parent->cursor();

    if (isVisible() && dataset != nullptr && cursor.distance.isValid()) {

        const int image_width = canvas.width();
        const int image_height = canvas.height();

        if(_image.width() != image_width || _image.height() != image_height) {
            _image = QImage(image_width, image_height, QImage::Format_Indexed8);
            _image.setColorTable(_colorLevels);
            _image.fill(0); //TODO: Does this help remove the side scan remaining artifact?
            _pixmap = QPixmap(image_width, image_height);
            //_pixmap.fill(Qt::black); //TODO: Does this help remove the side scan remaining artifact?
            resetCash(); //TODO: Does this help remove the side scan remaining artifact?
        }

        const int cash_width = canvas.width();

        const int cash_position = updateCash(parent, dataset, cash_width, image_height);

        QPainter p(&_pixmap);

        int cash_col = 0;
        while(cash_col < cash_width) {
            int cash_col_1 = cash_col;
            while(cash_col < cash_width && (_cash[cash_col].isNeedUpdate || _flagColorChanged)) {
                _cash[cash_col].isNeedUpdate = false;
                cash_col++;
            }

            int cash_update_width = cash_col - cash_col_1;

            if(cash_update_width > 0) {
                 p.drawImage(cash_col_1, 0, _image, cash_col_1, 0 , cash_update_width, 0, Qt::ThresholdDither); // Qt::NoOpaqueDetection |
            } else {
                cash_col++;
            }
        }

        _flagColorChanged = false;

        canvas.painter()->drawPixmap(0, 0, _pixmap, cash_position, 0, cash_width - cash_position, 0);
        canvas.painter()->drawPixmap(cash_width - cash_position, 0, _pixmap, 0, 0, cash_position, 0);
    } else {
    }

    return true;
}

bool Plot2DEchogram::drawZoomPreview(Plot2D* parent,
                                     Dataset* dataset,
                                     QPainter* painter,
                                     const QRect& targetRect,
                                     const QPoint& sourceCenter,
                                     int sourceSize,
                                     QPointF* focusPoint)
{
    return drawZoomPreview(parent, dataset, painter, targetRect, sourceCenter, sourceSize, sourceSize, focusPoint);
}

bool Plot2DEchogram::drawZoomPreview(Plot2D* parent,
                                     Dataset* dataset,
                                     QPainter* painter,
                                     const QRect& targetRect,
                                     const QPoint& sourceCenter,
                                     int sourceWidth,
                                     int sourceHeight,
                                     QPointF* focusPoint)
{
    //qDebug() << "zoom: New function drawZoomPreview fired";
    if (focusPoint) {
        *focusPoint = QPointF(0.5, 0.5);
    }

    if (!parent || !dataset || !painter || targetRect.width() <= 0 || targetRect.height() <= 0) {
        return false;
    }

    auto& cursor = parent->cursor();
    auto& canvas = parent->canvas();

    if (!cursor.distance.isValid() || canvas.width() <= 0 || canvas.height() <= 0) {
        return false;
    }

    const int previewWidth = targetRect.width();
    const int previewHeight = targetRect.height();
    if (previewWidth <= 0 || previewHeight <= 0) {
        return false;
    }

    const int srcWidth = qBound(4, sourceWidth, canvas.width());
    const int srcHeight = qBound(4, sourceHeight, canvas.height());

    const int clampedCenterX = qBound(0, sourceCenter.x(), canvas.width() - 1);
    const int clampedCenterY = qBound(0, sourceCenter.y(), canvas.height() - 1);

    const float cursorFrom = cursor.distance.from;
    const float cursorTo = cursor.distance.to;
    const float cursorRange = cursorTo - cursorFrom;
    if (qFuzzyIsNull(cursorRange)) {
        return false;
    }

    const float centerScale = static_cast<float>(clampedCenterY) / static_cast<float>(canvas.height());
    const float centerDistance = cursorFrom + centerScale * cursorRange;
    float distanceSpan = std::abs(cursorRange) * (static_cast<float>(srcHeight) / static_cast<float>(canvas.height()));
    if (distanceSpan < 0.01f) {
        distanceSpan = 0.01f;
    }

    const float minDistance = qMin(cursorFrom, cursorTo);
    const float maxDistance = qMax(cursorFrom, cursorTo);

    float low = centerDistance - distanceSpan * 0.5f;
    float high = centerDistance + distanceSpan * 0.5f;

    if (low < minDistance) {
        const float delta = minDistance - low;
        low += delta;
        high += delta;
    }
    if (high > maxDistance) {
        const float delta = high - maxDistance;
        low -= delta;
        high -= delta;
    }

    low = qBound(minDistance, low, maxDistance);
    high = qBound(minDistance, high, maxDistance);
    if (high <= low) {
        high = qMin(maxDistance, low + 0.01f);
    }

    const bool isAscending = cursorTo >= cursorFrom;
    const float zoomFrom = isAscending ? low : high;
    const float zoomTo = isAscending ? high : low;
    if (focusPoint) {
        const float zoomSpan = zoomTo - zoomFrom;
        float focusY = 0.5f;
        if (std::isfinite(zoomSpan) && std::abs(zoomSpan) > 1e-6f) {
            focusY = (centerDistance - zoomFrom) / zoomSpan;
        }
        focusY = qBound(0.0f, focusY, 1.0f);
        focusPoint->setX(0.5);
        focusPoint->setY(focusY);
    }

    const int sourceLeft = clampedCenterX - srcWidth / 2;
    if (miniPreviewPlot_ == nullptr) {
        miniPreviewPlot_ = new MiniPreviewPlot2D();
    }

    painter->save();
    painter->setClipRect(targetRect);
    painter->translate(targetRect.left(), targetRect.top());

    const bool rendered = miniPreviewPlot_->render(painter,
                                                   dataset,
                                                   cursor,
                                                   canvas.width(),
                                                   sourceLeft,
                                                   srcWidth,
                                                   previewWidth,
                                                   previewHeight,
                                                   zoomFrom,
                                                   zoomTo,
                                                   getThemeId(),
                                                   getLowLevel(),
                                                   getHighLevel(),
                                                   _compensation_id,
                                                   parent->getBottomTrackVisible(),
                                                   parent->getBottomTrackTheme(),
                                                   parent->getRangefinderVisible(),
                                                   parent->getRangefinderTheme());
    painter->restore();

    if (!rendered) {
        return false;
    }

    return true;
}

float Plot2DEchogram::getLowLevel() const
{
    return _levels.low;
}

float Plot2DEchogram::getHighLevel() const
{
    return _levels.high;
}
