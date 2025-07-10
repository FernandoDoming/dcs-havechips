@echo off
set OUTFILE=".\dist\havechips.lua"
del %OUTFILE%
echo ------------------- MOOSE ------------------- >> %OUTFILE%
type ..\..\Scripts\MOOSE_INCLUDE\Moose_Include_Static\Moose_.lua >> %OUTFILE%
echo ------------------- SPLASH DAMAGE ------------------- >> %OUTFILE%
type .\lib\Splash_Damage_3.3.lua >> %OUTFILE%
echo ------------------- EWRS ------------------- >> %OUTFILE%
type .\lib\EWRS.lua >> %OUTFILE%
echo ------------------- PERUN ------------------- >> %OUTFILE%
type .\src\Perun.lua >> %OUTFILE%
echo ------------------- HAVE CHIPS ------------------- >> %OUTFILE%
type .\src\HaveChipsMain.lua >> %OUTFILE%