@echo off
cd /d "%~dp0.."
if not exist "pruebas\classes" mkdir "pruebas\classes"
javac -encoding UTF-8 -d "pruebas\classes" -cp "WEB-INF\lib\mysql-connector-j-9.6.0.jar" "pruebas\PruebasInmobiliaria.java"
if errorlevel 1 (
    echo Error de compilacion de las pruebas.
    exit /b 1
)
java -cp "pruebas\classes;WEB-INF\lib\mysql-connector-j-9.6.0.jar" PruebasInmobiliaria