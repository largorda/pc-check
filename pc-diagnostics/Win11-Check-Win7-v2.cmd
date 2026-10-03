@echo off
setlocal EnableExtensions
title Windows 11 Compatibility Check - Windows 7
set "REPORT=%~dp0report2.txt"

if exist "%REPORT%" (
  echo.
  echo report2.txt already exists:
  echo %REPORT%
  echo Delete or rename report2.txt, then run this file again.
  echo.
  pause
  exit /b 1
)

call :HEAD "Windows 7 - Windows 11 compatibility diagnostic"
echo Report file: %REPORT%
echo.

echo [1/9] Windows information
call :SECTION "WINDOWS"
systeminfo
systeminfo >> "%REPORT%" 2>&1
echo.>>"%REPORT%"

echo.
echo [2/9] CPU
call :SECTION "CPU"
wmic cpu get Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,DataWidth,AddressWidth,Architecture,MaxClockSpeed
wmic cpu get Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,DataWidth,AddressWidth,Architecture,MaxClockSpeed 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

echo.
echo [3/9] PC / Mainboard / BIOS
call :SECTION "PC"
wmic computersystem get Manufacturer,Model,SystemType,TotalPhysicalMemory
wmic computersystem get Manufacturer,Model,SystemType,TotalPhysicalMemory 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

call :SECTION "MAINBOARD"
wmic baseboard get Manufacturer,Product,Version
wmic baseboard get Manufacturer,Product,Version 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

call :SECTION "BIOS"
wmic bios get Manufacturer,SMBIOSBIOSVersion,ReleaseDate
wmic bios get Manufacturer,SMBIOSBIOSVersion,ReleaseDate 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

echo.
echo [4/9] RAM
call :SECTION "RAM MODULES"
wmic memorychip get BankLabel,DeviceLocator,Capacity,Manufacturer,PartNumber,Speed
wmic memorychip get BankLabel,DeviceLocator,Capacity,Manufacturer,PartNumber,Speed 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

echo.
echo [5/9] Storage
call :SECTION "DISK DRIVES"
wmic diskdrive get Index,Model,Size,InterfaceType,MediaType
wmic diskdrive get Index,Model,Size,InterfaceType,MediaType 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

echo.
echo [6/9] Partitions / Volumes
call :SECTION "PARTITIONS"
wmic partition get DiskIndex,Index,Type,Size,BootPartition
wmic partition get DiskIndex,Index,Type,Size,BootPartition 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

call :SECTION "LOCAL VOLUMES"
wmic logicaldisk where "DriveType=3" get DeviceID,FileSystem,Size,FreeSpace
wmic logicaldisk where "DriveType=3" get DeviceID,FileSystem,Size,FreeSpace 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

echo.
echo [7/9] Graphics
call :SECTION "GRAPHICS"
wmic path Win32_VideoController get Name,AdapterCompatibility,AdapterRAM,DriverVersion
wmic path Win32_VideoController get Name,AdapterCompatibility,AdapterRAM,DriverVersion 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

echo.
echo [8/9] TPM
call :SECTION "TPM"
wmic /namespace:\\root\cimv2\security\microsofttpm path Win32_Tpm get SpecVersion,ManufacturerId,ManufacturerVersion,IsEnabled_InitialValue,IsActivated_InitialValue
wmic /namespace:\\root\cimv2\security\microsofttpm path Win32_Tpm get SpecVersion,ManufacturerId,ManufacturerVersion,IsEnabled_InitialValue,IsActivated_InitialValue 2>&1 | findstr /r /v "^$" >> "%REPORT%"
echo.>>"%REPORT%"

echo.
echo [9/9] Diagnostic notes
call :SECTION "WINDOWS 11 CHECK NOTES"
echo CPU official support: compare the exact CPU model with Microsoft's supported CPU list.
echo TPM requirement: TPM 2.0.
echo Firmware requirement: UEFI and Secure Boot capable.
echo RAM requirement: 4 GB or more.
echo Storage requirement: 64 GB or more.
echo Graphics requirement: DirectX 12 compatible GPU with WDDM 2.0 driver.
echo.
(
  echo CPU official support: compare the exact CPU model with Microsoft's supported CPU list.
  echo TPM requirement: TPM 2.0.
  echo Firmware requirement: UEFI and Secure Boot capable.
  echo RAM requirement: 4 GB or more.
  echo Storage requirement: 64 GB or more.
  echo Graphics requirement: DirectX 12 compatible GPU with WDDM 2.0 driver.
) >> "%REPORT%"

echo.
echo ============================================================
echo COMPLETE - report2.txt was created.
echo ============================================================
echo.

echo ---------------- SAVED REPORT CONTENT ----------------
type "%REPORT%"
echo ---------------- END OF REPORT ------------------------
echo.

start "" notepad.exe "%REPORT%"
echo report2.txt was also opened in Notepad.
echo.
pause
exit /b 0

:HEAD
> "%REPORT%" echo ============================================================
>>"%REPORT%" echo %~1
>>"%REPORT%" echo ============================================================
>>"%REPORT%" echo.
exit /b 0

:SECTION
echo.
echo ===== %~1 =====
>>"%REPORT%" echo ===== %~1 =====
exit /b 0
