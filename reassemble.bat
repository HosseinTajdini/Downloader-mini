@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo    FILE REASSEMBLER TOOL (Windows)
echo ========================================
echo.
echo This tool reassembles split files (.part*)
echo No Python or extra software required!
echo.

:: Get chunks directory
set "chunks_dir="
set /p "chunks_dir=Enter path to chunks folder (or drag & drop here): "

:: Remove quotes if any
set "chunks_dir=%chunks_dir:"=%"

:: Remove trailing backslash if exists
if "%chunks_dir:~-1%"=="\" set "chunks_dir=%chunks_dir:~0,-1%"

:: Check if directory exists
if not exist "%chunks_dir%" (
    echo.
    echo [ERROR] Folder not found: %chunks_dir%
    pause
    exit /b 1
)

echo.
echo [OK] Folder found: %chunks_dir%
cd /d "%chunks_dir%" 2>nul

:: Try to guess original filename from part files
set "output_file=restored_file"
set "found_name="

:: Look for the first part file to extract base name
for %%f in (*.part001.*) do (
    set "found_name=%%~nf"
    goto :extract_name
)
for %%f in (*.part001) do (
    set "found_name=%%~nf"
    goto :extract_name
)
for %%f in (*.part01.*) do (
    set "found_name=%%~nf"
    goto :extract_name
)
for %%f in (*.part1.*) do (
    set "found_name=%%~nf"
    goto :extract_name
)
for %%f in (*.part*) do (
    set "found_name=%%~nf"
    goto :extract_name
)

:extract_name
if defined found_name (
    :: Remove the .partXXX suffix
    set "output_file=!found_name:.part001=!"
    set "output_file=!output_file:.part01=!"
    set "output_file=!output_file:.part1=!"
    set "output_file=!output_file:.part=!"
    
    :: Add back the extension from the first part
    for %%f in ("%chunks_dir%\!found_name!.*") do (
        set "ext=%%~xf"
        if not "!ext!"=="" set "output_file=!output_file!!ext!"
        goto :done_ext
    )
    :done_ext
    echo [INFO] Detected original filename: !output_file!
)

:: Get custom output filename
echo.
set "custom_name="
set /p "custom_name=Enter output filename (or press Enter for auto): "
if not "!custom_name!"=="" set "output_file=!custom_name!"

:: Make sure output has full path
if "!output_file!"=="!output_file!" (
    if not "!output_file:~0,2!"=="\\" (
        if not "!output_file:~1,1!"==":" (
            set "output_file=%chunks_dir%\!output_file!"
        )
    )
)

echo.
echo ========================================
echo Reassembling files...
echo ========================================

:: Count part files
set "part_count=0"
for %%f in ("%chunks_dir%\*.part*") do (
    set /a part_count+=1
)

if %part_count%==0 (
    echo [ERROR] No .part files found in %chunks_dir%
    echo.
    echo Make sure the folder contains files like: filename.part001.zip
    pause
    exit /b 1
)

echo [INFO] Found %part_count% part file(s)

:: Build sorted list and merge
echo [INFO] Assembling...

:: Create a temporary file with sorted list
set "temp_list=%temp%\part_list.txt"
dir /b "%chunks_dir%\*.part*" | sort > "%temp_list%"

:: Build the copy command
set "copy_cmd=copy /b"

:: Add each part file
for /f "usebackq delims=" %%f in ("%temp_list%") do (
    echo   Adding: %%f
    set "copy_cmd=!copy_cmd! "%chunks_dir%\%%f" +"
)

:: Remove the last "+"
set "copy_cmd=!copy_cmd:~0,-2!"

:: Add output file
set "copy_cmd=!copy_cmd! "!output_file!""

:: Execute merge
!copy_cmd! >nul 2>&1

:: Clean temp file
del "%temp_list%" 2>nul

:: Check result
if exist "!output_file!" (
    for %%a in ("!output_file!") do set "file_size=%%~za"
    set /a size_mb=!file_size! / 1048576
    set /a size_kb=!file_size! / 1024
    
    echo.
    echo ========================================
    echo    ✓ SUCCESS!
    echo ========================================
    echo Output file: !output_file!
    if !size_mb! gtr 0 (
        echo File size: !size_mb! MB
    ) else (
        echo File size: !size_kb! KB
    )
    echo.
    
    :: Verify with manifest if exists
    if exist "manifest.json" (
        echo [INFO] Manifest found - file should be correct
    )
    
    :: Ask about deleting chunks
    echo.
    set "delete_chunks="
    set /p "delete_chunks=Delete the chunk files to save space? (Y/N): "
    if /i "!delete_chunks!"=="Y" (
        echo Deleting chunk files...
        del /q "%chunks_dir%\*.part*" 2>nul
        if exist "%chunks_dir%\manifest.json" del /q "%chunks_dir%\manifest.json"
        echo [OK] Cleanup complete.
    )
) else (
    echo.
    echo ========================================
    echo    ✗ ERROR!
    echo ========================================
    echo Failed to reassemble file!
    echo.
    echo Possible issues:
    echo - Part files might be corrupted
    echo - Part files might be from different sources
    echo - Not enough disk space
)

echo.
pause
exit /b 0
