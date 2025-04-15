#include "draw_utils.h"


sscan::PlotColorTable::PlotColorTable()
{
    setThemeById(static_cast<int>(ThemeId::ClassicTheme));
    setLevels(10.0f, 100.0f);
}

void sscan::PlotColorTable::setThemeById(int id)
{
    ThemeId theme;
    if (id >= static_cast<int>(ThemeId::ClassicTheme) && id <= static_cast<int>(ThemeId::SepiaTemeExtra)) {
        theme = static_cast<ThemeId>(id);
    }
    else {
        return;
    }

    QVector<QColor> colors;
    QVector<int> levels;

    switch (theme) {

    case ThemeId::ClassicTheme: {
        colors = {
                   QColor("#000000"),
                   QColor("#0e1318"),
                   QColor("#152029"),
                   QColor("#1a2c3a"),
                   QColor("#1f394d"),
                   QColor("#234760"),
                   QColor("#275575"),
                   QColor("#2a6389"),
                   QColor("#2d729f"),
                   QColor("#2f82b5"),
                   QColor("#3191cb"),
                   QColor("#32a1e2")};

        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };
        break;
    }
    case ThemeId::SepiaTheme: {
        colors = {
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
        break;
    }
    case ThemeId::WBTheme: {
        colors = {
                   QColor("#000000"),
                   QColor("#171717"),
                   QColor("#262727"),
                   QColor("#373838"),
                   QColor("#484a4a"),
                   QColor("#5a5d5d"),
                   QColor("#6d7171"),
                   QColor("#808585"),
                   QColor("#949999"),
                   QColor("#a8aeae"),
                   QColor("#bdc4c4"),
                   QColor("#d2dada")};

        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };
        break;
    }
    case ThemeId::RedTheme: {
        colors = {
                   QColor("#000000"),
                   QColor("#1b0f08"),
                   QColor("#2c1810"),
                   QColor("#3f2015"),
                   QColor("#522819"),
                   QColor("#67301d"),
                   QColor("#7c3821"),
                   QColor("#914025"),
                   QColor("#a74929"),
                   QColor("#be512d"),
                   QColor("#d55a31"),
                   QColor("#ed6335")};


        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };
        break;
    }
    case ThemeId::GreenTheme: {
        colors = {
                   QColor("#000000"),
                   QColor("#11180e"),
                   QColor("#1a2916"),
                   QColor("#233a1d"),
                   QColor("#2c4d24"),
                   QColor("#35602b"),
                   QColor("#3e7432"),
                   QColor("#478939"),
                   QColor("#519e40"),
                   QColor("#5ab447"),
                   QColor("#63ca4f"),
                   QColor("#6de156")};


        levels = { 0, 23, 46, 70, 93, 116, 139, 162, 185, 209, 232, 255 };
        break;
    }
    case ThemeId::Ek500BlackTheme: {
        colors = {
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
        break;
    }
    case ThemeId::Ek500WhiteTheme: {
        colors = {
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
        break;
    }
    case ThemeId::FurunoBlackTheme: {
        colors = {
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
        break;
    }
    case ThemeId::FurunoWhiteTheme: {
        colors = {
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
        break;
    }
    case ThemeId::KaijoBlackTheme: {
        //This is SONIC black
        colors = {
            QColor::fromRgb(  0,   0,   0),
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
        break;
    }
    case ThemeId::KaijoWhiteTheme: {
        //This is SONIC white
        colors = {
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
        break;
    }
    case ThemeId::SepiaTemeExtra: {
        colors = {
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
        break;
    }



    /*
    case ThemeId::kClassic: {
        colors = { QColor::fromRgb(0,   0,   0),
                   QColor::fromRgb(20,  5,   80),
                   QColor::fromRgb(50,  180, 230),
                   QColor::fromRgb(190, 240, 250),
                   QColor::fromRgb(255, 255, 255) };
        levels = { 0, 30, 130, 220, 255 };
        break;
    }
    case ThemeId::kSepia: {
        colors = { QColor::fromRgb(0,   0,   0),
                   QColor::fromRgb(50,  50,  10),
                   QColor::fromRgb(230, 200, 100),
                   QColor::fromRgb(255, 255, 220) };
        levels = { 0, 30, 130, 255 };
        break;
    }
    case ThemeId::kWRGBD: {
        colors = { QColor::fromRgb(0,   0,   0),
                   QColor::fromRgb(40,  0,   80),
                   QColor::fromRgb(0,   30,  150),
                   QColor::fromRgb(20,  230, 30),
                   QColor::fromRgb(255, 50,  20),
                   QColor::fromRgb(255, 255, 255) };
        levels = { 0, 30, 80, 120, 150, 255 };

        break;
    }
    case ThemeId::kWB: {
        colors = { QColor::fromRgb(0,   0,   0),
                   QColor::fromRgb(190, 200, 200),
                   QColor::fromRgb(230, 255, 255) };
        levels = { 0, 150, 255 };
        break;
    }
    case ThemeId::kBW: {
        colors = { QColor::fromRgb(230, 255, 255),
                   QColor::fromRgb(70,  70,  70),
                   QColor::fromRgb(0,   0,   0) };
        levels = { 0, 150, 255 };
        break;
    }
    */
    default:
        break;
    }

    setColorScheme(colors, levels);
}

void sscan::PlotColorTable::setLevels(float low, float high)
{
    lowLevel_ = low;
    highLevel_ = high;

    update();
}

void sscan::PlotColorTable::setLowLevel(float val)
{
    setLevels(val, highLevel_);
}

void sscan::PlotColorTable::setHighLevel(float val)
{
    setLevels(lowLevel_, val);
}

QVector<QRgb> sscan::PlotColorTable::getColorTable() const
{
    return colorTableWithLevels_;
}

std::vector<uint8_t> sscan::PlotColorTable::getRgbaColors() const
{
    return rgbaColors_;
}

void sscan::PlotColorTable::update()
{
    int levelRange = highLevel_ - lowLevel_;
    int indexOffset = static_cast<int>(lowLevel_ * 2.5f);
    float indexMapScale = 0;

    if (levelRange > 0) {
        indexMapScale = static_cast<float>((256 - 1) / ((highLevel_ - lowLevel_) * 2.55f));
    }
    else {
        indexMapScale = 10000.0f;
    }

    for (int i = 0; i < colorTable_.size(); i++) {
        int indexMap = static_cast<int>((i - indexOffset) * indexMapScale);

        if (indexMap < 0) {
            indexMap = 0;
        }
        else if (indexMap > 255) {
            indexMap = 255;
        }

        colorTableWithLevels_[i] = colorTable_[indexMap];
    }

    int colorCount = colorTableWithLevels_.size();
    rgbaColors_.resize(colorCount * 4);
    for (int i = 0; i < colorCount; ++i) {
        QRgb color = colorTableWithLevels_[i];
        rgbaColors_[i * 4 + 0] = static_cast<uint8_t>(qRed(color));
        rgbaColors_[i * 4 + 1] = static_cast<uint8_t>(qGreen(color));
        rgbaColors_[i * 4 + 2] = static_cast<uint8_t>(qBlue(color));
        rgbaColors_[i * 4 + 3] = static_cast<uint8_t>(qAlpha(color));
    }
}

void sscan::PlotColorTable::setColorScheme(const QVector<QColor> &colors, const QVector<int> &levels)
{
    if (colors.length() != levels.length()) {
        return;
    }

    colorTable_.resize(256);
    colorTableWithLevels_.resize(256);

    int nbrLevels = colors.length() - 1;
    int iLevel = 0;

    for (int i = 0; i < nbrLevels; ++i) {
        while (levels[i + 1] >= iLevel) {
            float bCoef = static_cast<float>((iLevel - levels[i])) / static_cast<float>((levels[i + 1] - levels[i]));
            float aCoef = 1.0f - bCoef;

            int red   = qRound(colors[i].red()   * aCoef + colors[i + 1].red()   * bCoef);
            int green = qRound(colors[i].green() * aCoef + colors[i + 1].green() * bCoef);
            int blue  = qRound(colors[i].blue()  * aCoef + colors[i + 1].blue()  * bCoef);

            colorTable_[iLevel] = qRgb(red, green, blue);
            ++iLevel;
        }
    }

    update();
}
