@echo off
set QT_BIN=C:\Qt\5.15.2\mingw81_64\bin
set PROJECT_PATH=C:\Users\OlavAamaas\QTprojects\KoggerApp\KoggerApp
set LANG_PATH=%PROJECT_PATH%\languages

"%QT_BIN%\lupdate" "%PROJECT_PATH%\KoggerApp.pro" -ts "%LANG_PATH%\translation_en.ts"
"%QT_BIN%\lupdate" "%PROJECT_PATH%\KoggerApp.pro" -ts "%LANG_PATH%\translation_ru.ts"
"%QT_BIN%\lupdate" "%PROJECT_PATH%\KoggerApp.pro" -ts "%LANG_PATH%\translation_pl.ts"
"%QT_BIN%\lupdate" "%PROJECT_PATH%\KoggerApp.pro" -ts "%LANG_PATH%\translation_de.ts"

echo Translations updated.
pause