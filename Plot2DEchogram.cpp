#include "Plot2D.h"


Plot2DEchogram::Plot2DEchogram() {
    setThemeId(ClassicTheme);
    setLevels(10, 100);
}

void Plot2DEchogram::setLowLevel(float low) {
    setLevels(low, _levels.high);
}

void Plot2DEchogram::setHightLevel(float high) {
    setLevels(_levels.low, high);
}

void Plot2DEchogram::setLevels(float low, float high) {
    _levels.low = low;
    _levels.high = high;
    updateColors();
}

void Plot2DEchogram::setColorScheme(QVector<QColor> coloros, QVector<int> levels) {
    if(coloros.length() != levels.length()) { return; }

    _colorTable.resize(256);
    _colorLevels.resize(256);

    int nbr_levels = coloros.length() - 1;
    int i_level = 0;

    for(int i = 0; i < nbr_levels; i++) {
        while(levels[i + 1] >= i_level) {
            float b_koef = (float)(i_level - levels[i]) / (float)(levels[i + 1] - levels[i]);
            float a_koef = 1.0f - b_koef;

            int red = qRound(coloros[i].red()*a_koef + coloros[i + 1].red()*b_koef);
            int green = qRound(coloros[i].green()*a_koef + coloros[i + 1].green()*b_koef);
            int blue = qRound(coloros[i].blue()*a_koef + coloros[i + 1].blue()*b_koef);
            _colorHashMap[i_level] = ((red / 8) << 10) | ((green / 8) << 5) | ((blue / 8));

            _colorTable[i_level] = qRgb(red, green, blue);
            i_level++;
        }
    }

    updateColors();
}

void Plot2DEchogram::setThemeId(int theme_id) {
    QVector<QColor> coloros;
    QVector<int> levels;

    if(theme_id == ClassicTheme) {
        coloros = {
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


        /*
        coloros = {
            QColor::fromRgb(  0,   0,   0),
            QColor::fromRgb( 20,   5,  80),
            QColor::fromRgb( 50, 180, 230),
            QColor::fromRgb(190, 240, 250),
            QColor::fromRgb(255, 255, 255)};

        levels = {0, 30, 130, 220, 255};
        */

    } else if(theme_id == SepiaTheme) {

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

        /* Similar to Garmin
        coloros = {
           QColor::fromRgb(  0,   0,   0),
           QColor::fromRgb( 35,  17,  11),
           QColor::fromRgb(191, 117,  97),
           QColor::fromRgb(232, 148,  32)};

        /// Origonal sepia

        coloros = {
            QColor::fromRgb(  0,   0,   0),
            QColor::fromRgb( 50,  50,  10),
            QColor::fromRgb(230, 200, 100),
            QColor::fromRgb(255, 255, 220)};

        levels = {0, 30, 130, 255};
        */

    } else if(theme_id == WBTheme) {
        coloros = {
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



        /*

        coloros = {

            QColor::fromRgb(0, 0, 0),
            QColor::fromRgb(190, 200, 200),
            QColor::fromRgb(230, 255, 255)};

        levels = {0, 150, 255};
*/

    } else if(theme_id == RedTheme) {
        coloros = {
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

        /*
        coloros = {
           QColor::fromRgb(  0,   0,   0),
           QColor::fromRgb( 50,  10,  10),
           QColor::fromRgb(160,  55,  22),
           QColor::fromRgb(225,  65,  12)};

        levels = {0, 30, 130, 255};
*/

    } else if(theme_id == GreenTheme) {
        coloros = {
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

        /*
        coloros = {
           QColor::fromRgb(  0,   0,   0),
           QColor::fromRgb( 50,  10,  10),
           QColor::fromRgb(160,  55,  22),
           QColor::fromRgb(225,  65,  12)};

        levels = {0, 30, 130, 255};

*/

    } else if(theme_id == Ek500BlackTheme) {
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

        /*

        coloros = {
           QColor::fromRgb(  0,   0,   0),
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
           QColor::fromRgb(120,  60,  40)};

        levels = { 0, 21, 42, 64, 85, 106, 128, 149, 170, 191, 212, 234, 255 };
        */


    } else if(theme_id == Ek500WhiteTheme) {

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

        /*
        coloros = {
           QColor::fromRgb(255, 255, 255),
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
           QColor::fromRgb(120,  60,  40)};

        levels = { 0, 21, 42, 64, 85, 106, 128, 149, 170, 191, 212, 234, 255 };
        */

    } else if(theme_id == FurunoBlackTheme) {

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

    } else if(theme_id == FurunoWhiteTheme) {

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

    } else if(theme_id == KaijoBlackTheme) {

        //This is SONIC black
        coloros = {
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

        /*
        coloros = {
           QColor::fromRgb(  0,   0,   0),
           QColor::fromRgb(160, 224, 192),
           QColor::fromRgb(129, 193, 224),
           QColor::fromRgb(  0, 129, 223),
           QColor::fromRgb( 64, 128, 128),
           QColor::fromRgb(  0, 223, 129),
           QColor::fromRgb(  0, 223,   0),
           QColor::fromRgb(  0, 159,   0),
           QColor::fromRgb(  0,  96,   0),
           QColor::fromRgb(128, 128,  64),
           QColor::fromRgb(140, 140, 115),
           QColor::fromRgb(255, 128,   0),
           QColor::fromRgb(255, 128, 128),
           QColor::fromRgb(255,   0,   0),
           QColor::fromRgb(128,   0,   0),
           QColor::fromRgb( 64,   0,   0)};

        levels = { 0, 17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255 };
        */

    } else if(theme_id == KaijoWhiteTheme) {

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

        /*

        coloros = {
            QColor::fromRgb(255, 255, 255),
            QColor::fromRgb(160, 224, 192),
            QColor::fromRgb(129, 193, 224),
            QColor::fromRgb(  0, 129, 223),
            QColor::fromRgb( 64, 128, 128),
            QColor::fromRgb(  0, 223, 129),
            QColor::fromRgb(  0, 223,   0),
            QColor::fromRgb(  0, 159,   0),
            QColor::fromRgb(  0,  96,   0),
            QColor::fromRgb(128, 128,  64),
            QColor::fromRgb(140, 140, 115),
            QColor::fromRgb(255, 128,   0),
            QColor::fromRgb(255, 128, 128),
            QColor::fromRgb(255,   0,   0),
            QColor::fromRgb(128,   0,   0),
            QColor::fromRgb( 64,   0,   0)};

        levels = { 0, 17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255 };
        */

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

            /* Similar to Garmin
        coloros = {
           QColor::fromRgb(  0,   0,   0),
           QColor::fromRgb( 35,  17,  11),
           QColor::fromRgb(191, 117,  97),
           QColor::fromRgb(232, 148,  32)};

        /// Origonal sepia

        coloros = {
            QColor::fromRgb(  0,   0,   0),
            QColor::fromRgb( 50,  50,  10),
            QColor::fromRgb(230, 200, 100),
            QColor::fromRgb(255, 255, 220)};

        levels = {0, 30, 130, 255};
        */

        };

    setColorScheme(coloros, levels);
}

void Plot2DEchogram::setCompensation(int compensation_id) {
    _compensation_id = compensation_id;
}

void Plot2DEchogram::updateColors() {
    float low = _levels.low;
    float high = _levels.high;

    int level_range = high - low;
    int index_offset = (int)((float)low*2.5f);
    float index_map_scale = 0;
    if(level_range > 0) {
        index_map_scale = (float)(256 - 1)/((float)(high - low)*2.55f);
    } else {
        index_map_scale = 10000;
    }

    for(int i = 0; i < _colorTable.size(); i++) {
        int index_map = ((float)(i - index_offset)*index_map_scale);
        if(index_map < 0) { index_map = 0; }
        else if(index_map > 255) { index_map = 255; }
        _colorLevels[i] = _colorTable[index_map];
    }

    _flagColorChanged = true;
    _image.setColorTable(_colorLevels);
}

void Plot2DEchogram::resetCash() {
    _cashFlags.resetCash = true;
}

int Plot2DEchogram::updateCash(Dataset* dataset, DatasetCursor cursor, int width, int height) {
    if(_cash.size() != width) {
        _cash.resize(width);
        resetCash();
    }

    uint8_t* image_data = (uint8_t*)_image.constBits();
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

    if(to >= 0) {
        range1 = 0 - from;
        from1 = 0;
        to1 = -from;

        if(from >= 0) { from2 = from; }
        else { from2 = 0; }
        to2 = to;
    } else {
        range1 = to - from;
        from1 = -to;
        to1 = -from;
    }

    int cash_validate = 0;

    int wrap_start_pos = qAbs(cursor.getIndex(0) % width);

    for(unsigned int i = 0; i < cursor.indexes.size(); i++) {
        if(cursor.indexes[i] > 0) {
            wrap_start_pos = qAbs((cursor.indexes[i] + (width - i)) % width);
            break;
        }
    }


//    _cashPosition = wrap_start_pos;
    for(int column = 0; column < width; column++) {
        if(_cash[column].data.size() != height) {
//            _cash[column].stateColor = CashLine::CashStateNotValid;
            _cash[column].state = CashLine::CashStateNotValid;
            _cash[column].data.resize(height);
//            _cash[column].data.fill(0);
            _cash[column].poolIndex = -1;
            _cash[column].state = CashLine::CashStateEraced;
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

        int cursor_pos = column - wrap_start_pos;
        if(column < wrap_start_pos) {
            cursor_pos += width;
        }

        int pool_index = cursor.getIndex(cursor_pos);
        int pool_index_safe = dataset->validIndex(pool_index);
        if(pool_index_safe >= 0) {
            const int cash_index = _cash[column].poolIndex;
            if(is_cash_notvalid || pool_index_safe != cash_index) {
                _cash[column].poolIndex = pool_index_safe;

                Epoch* datasource = dataset->fromIndex(pool_index_safe);
                if(datasource != NULL) {
                    _cash[column].state = CashLine::CashStateNotValid;
                    int16_t* cash_data = _cash[column].data.data();
                    int16_t cash_data_size = _cash[column].data.size();

                    if(cursor.channel2 == CHANNEL_NONE) {
                        datasource->chartTo(cursor.channel1, from, to, cash_data, cash_data_size, _compensation_id);
                    } else {
                        int cash_data_size_part1 = cash_data_size*(range1/fullrange);

                        if(cash_data_size_part1 > 0) {
                            datasource->chartTo(cursor.channel1, from1, to1, cash_data, cash_data_size_part1, _compensation_id, true);
                        }

                        if(cash_data_size_part1 < 0) {
                            cash_data_size_part1 = 0;
                        }

                        const int cash_data_size_part2 = cash_data_size - cash_data_size_part1;
                        if(cash_data_size_part2 > 0) {
                            datasource->chartTo(cursor.channel2, from2, to2, &cash_data[cash_data_size_part1], cash_data_size_part2, _compensation_id, false);
                        }
                    }

                    cash_validate++;

                    _cash[column].state = CashLine::CashStateValid;
                    _cash[column].isNeedUpdate = true;
                    uint8_t * img_data = image_data + column;
                    for (int image_row = 0; image_row < cash_data_size; image_row++) {
                        *img_data = *cash_data;
                        img_data += b_scanline;
                        cash_data++;
                    }
//                    _cash[column].stateColor = CashLine::CashStateNotValid;
                } else {
                    if(_cash[column].state != CashLine::CashStateEraced) {
//                        _cash[column].stateColor = CashLine::CashStateNotValid;
                        _cash[column].state = CashLine::CashStateNotValid;
                        _cash[column].data.fill(0);
                        _cash[column].poolIndex = -1;
                        _cash[column].state = CashLine::CashStateEraced;
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
            if(_cash[column].state != CashLine::CashStateEraced) {
//                _cash[column].stateColor = CashLine::CashStateNotValid;
                _cash[column].state = CashLine::CashStateNotValid;
                _cash[column].data.fill(0);
                _cash[column].poolIndex = -1;
                _cash[column].state = CashLine::CashStateEraced;
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

    return wrap_start_pos;
}

bool Plot2DEchogram::draw(Canvas& canvas, Dataset* dataset, DatasetCursor cursor) {
    if(isVisible() && dataset != nullptr && cursor.distance.isValid()) {
        const int image_width = canvas.width();
        const int image_height = canvas.height();

        if(_image.width() != image_width || _image.height() != image_height) {
            _image = QImage(image_width, image_height, QImage::Format_Indexed8);
            _image.setColorTable(_colorLevels);
            _pixmap = QPixmap(image_width, image_height);
        }

        const int cash_width = canvas.width();

        const int cash_position = updateCash(dataset, cursor, cash_width, image_height);

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


