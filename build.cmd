@echo off
set OUTFILE=".\dist\havechips.lua"
del %OUTFILE%
echo ------------------- MOOSE.lua ------------------- >> %OUTFILE%
type ..\..\Scripts\MOOSE_INCLUDE\Moose_Include_Static\Moose_.lua >> %OUTFILE%
echo ------------------- SPLASH DAMAGE ------------------- >> %OUTFILE%
type .\lib\Splash_Damage_3.3.lua >> %OUTFILE%
echo ------------------- EWRS.lua ------------------- >> %OUTFILE%
type .\lib\EWRS.lua >> %OUTFILE%
echo ------------------- HC.Perun.lua ------------------- >> %OUTFILE%
type .\src\HC.Perun.lua >> %OUTFILE%
echo ------------------- HaveChipsMain.lua ------------------- >> %OUTFILE%
type .\src\HaveChipsMain.lua >> %OUTFILE%
echo ------------------- HC.AirbaseInfo.lua ------------------- >> %OUTFILE%
type .\src\HC.AirbaseInfo.lua >> %OUTFILE%
echo ------------------- HC.Builders.lua ------------------- >> %OUTFILE%
type .\src\HC.Builders.lua >> %OUTFILE%
echo ------------------- HC.Utils.lua ------------------- >> %OUTFILE%
type .\src\HC.Utils.lua >> %OUTFILE%