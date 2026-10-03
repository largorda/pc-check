@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Windows 7 CMD/WMIC queries only. Report writes use append after an existence check.
rem ASCII text only, without BOM, with CRLF, for Windows 7 CMD.
rem No code-page, registry, firmware, boot, service or driver settings are changed.

set "W11_REPORT=%~dp0report.txt"
set "W11_WRITE_FAILED="
set "W11_WMIC=%SystemRoot%\System32\wbem\WMIC.exe"
if exist "%SystemRoot%\Sysnative\wbem\WMIC.exe" set "W11_WMIC=%SystemRoot%\Sysnative\wbem\WMIC.exe"

if exist "%W11_REPORT%" goto ExistingReport

>>"%W11_REPORT%" echo Windows 7 - Windows 11 compatibility information
if errorlevel 1 goto ReportWriteFailed
if not exist "%W11_REPORT%" goto ReportWriteFailed
>>"%W11_REPORT%" echo.
>>"%W11_REPORT%" echo Read-only query results. Only this report file is created; no settings are changed.
>>"%W11_REPORT%" echo Failed queries or empty results are marked "Unavailable".
>>"%W11_REPORT%" echo Blank property values mean missing information, not proof that a feature is unsupported.
>>"%W11_REPORT%" echo Size/Capacity/TotalPhysicalMemory values are in bytes.
>>"%W11_REPORT%" echo This report does not automatically confirm official CPU support or Windows 11 eligibility.

echo [1/8] Checking Windows information...
>>"%W11_REPORT%" echo.
>>"%W11_REPORT%" echo ===== [1/8] Windows =====
call :QueryWmi os get Caption,Version,BuildNumber,OSArchitecture,CSDVersion,ServicePackMajorVersion,ServicePackMinorVersion,SystemDrive

echo [2/8] Checking CPU...
>>"%W11_REPORT%" echo ===== [2/8] CPU =====
call :QueryWmi cpu get Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,DataWidth,AddressWidth,Architecture,MaxClockSpeed
>>"%W11_REPORT%" echo CPU generation and official Microsoft support: Unavailable - compare the exact model with vendor specifications and Microsoft lists.
>>"%W11_REPORT%" echo DataWidth is the CPU bit width; AddressWidth is the current OS address width. They may differ.
>>"%W11_REPORT%" echo MaxClockSpeed is in MHz. Bit width, clock speed and core count alone do not establish official CPU support.

echo [3/8] Checking PC, mainboard and BIOS...
>>"%W11_REPORT%" echo ===== [3/8] PC / Mainboard / BIOS =====
>>"%W11_REPORT%" echo [PC]
call :QueryWmi computersystem get Manufacturer,Model,SystemType
>>"%W11_REPORT%" echo [Mainboard]
call :QueryWmi baseboard get Manufacturer,Product,Version
>>"%W11_REPORT%" echo [BIOS]
call :QueryWmi bios get Manufacturer,SMBIOSBIOSVersion,ReleaseDate
>>"%W11_REPORT%" echo BIOS date is the original WMI date string, such as YYYYMMDDhhmmss...
>>"%W11_REPORT%" echo Current UEFI/Legacy boot mode: Unavailable - Windows 7 WMIC alone does not confirm it.
>>"%W11_REPORT%" echo UEFI support and BIOS update options: Unavailable - consult official documentation for the exact PC/mainboard model.

echo [4/8] Checking RAM...
>>"%W11_REPORT%" echo ===== [4/8] RAM =====
>>"%W11_REPORT%" echo [System-reported physical memory]
call :QueryWmi computersystem get TotalPhysicalMemory
>>"%W11_REPORT%" echo [Memory modules]
call :QueryWmi memorychip get BankLabel,DeviceLocator,Capacity,Manufacturer,PartNumber,Speed
>>"%W11_REPORT%" echo [Memory arrays]
call :QueryWmi path Win32_PhysicalMemoryArray get MemoryDevices,MaxCapacity
>>"%W11_REPORT%" echo Compare installed RAM with the sum of Capacity values for all memory modules.
>>"%W11_REPORT%" echo TotalPhysicalMemory may be below installed RAM due to reserved memory or 32-bit OS limits.
>>"%W11_REPORT%" echo MemoryDevices is the WMI-reported slot count per memory array; MaxCapacity is in KB.

echo [5/8] Checking storage devices...
>>"%W11_REPORT%" echo ===== [5/8] Storage devices =====
call :QueryWmi diskdrive get Index,Model,Size,InterfaceType,MediaType
>>"%W11_REPORT%" echo HDD/SSD type: Unavailable - check vendor specifications for the exact drive model.
>>"%W11_REPORT%" echo The MediaType value Fixed hard disk media does not distinguish HDD from SSD.
>>"%W11_REPORT%" echo Windows 11 requires at least 64 GB of storage; an SSD is not mandatory.

echo [6/8] Checking disk partitions...
>>"%W11_REPORT%" echo ===== [6/8] Partitions and local volumes =====
>>"%W11_REPORT%" echo [Partitions]
call :QueryWmi partition get DiskIndex,Index,Name,Type,Size,BootPartition,Bootable
>>"%W11_REPORT%" echo [Fixed local volumes only]
call :QueryWmi logicaldisk where "DriveType=3" get DeviceID,FileSystem,Size,FreeSpace
>>"%W11_REPORT%" echo [Logical disk to partition associations]
call :QueryWmi path Win32_LogicalDiskToPartition get Antecedent,Dependent
>>"%W11_REPORT%" echo Do not assume the system disk is Disk 0 or C:. Compare Windows SystemDrive with the associations.
>>"%W11_REPORT%" echo Confirmed MBR/GPT status: Unavailable - raw Type values are reported; no GPT label does not prove MBR.
>>"%W11_REPORT%" echo Only partition queries are performed; partition and boot configurations are not changed.

echo [7/8] Checking graphics...
>>"%W11_REPORT%" echo ===== [7/8] Graphics =====
call :QueryWmi path Win32_VideoController get Name,AdapterCompatibility,AdapterRAM,DriverVersion
>>"%W11_REPORT%" echo AdapterRAM is in bytes. Its 32-bit WMI field may be inaccurate at 4 GiB or more.
>>"%W11_REPORT%" echo DirectX 12 support: Unavailable - check official GPU specifications and Windows 11 driver support.
>>"%W11_REPORT%" echo WDDM version: Unavailable - graphics diagnostic tools that create extra files are not run.

echo [8/8] Checking TPM and Secure Boot information...
>>"%W11_REPORT%" echo ===== [8/8] TPM / Secure Boot =====
>>"%W11_REPORT%" echo [TPM WMI properties only]
call :QueryWmi /namespace:\\root\cimv2\security\microsofttpm path Win32_Tpm get SpecVersion,ManufacturerId,ManufacturerVersion,IsEnabled_InitialValue,IsActivated_InitialValue
>>"%W11_REPORT%" echo Check the first SpecVersion entry for the TPM version; ManufacturerVersion is the separate firmware version.
>>"%W11_REPORT%" echo A failed TPM query does not prove that TPM is absent or TPM 2.0 is unsupported.
>>"%W11_REPORT%" echo Intel PTT / AMD fTPM support: Unavailable - consult official documentation for the exact PC/mainboard model.
>>"%W11_REPORT%" echo Secure Boot support and current enabled state: Unavailable - Windows 7 WMIC has no safe standard query for these.
>>"%W11_REPORT%" echo UEFI support alone does not confirm Secure Boot support; registry and firmware settings are not changed.
>>"%W11_REPORT%" echo.
>>"%W11_REPORT%" echo ===== Windows 11 comparison checklist =====
>>"%W11_REPORT%" echo CPU: Microsoft-supported 64-bit CPU/SoC, at least 1 GHz and at least 2 cores
>>"%W11_REPORT%" echo RAM: At least 4 GB
>>"%W11_REPORT%" echo Storage: At least 64 GB and free space for installation and updates
>>"%W11_REPORT%" echo Firmware: UEFI, Secure Boot capable / TPM: 2.0
>>"%W11_REPORT%" echo Graphics: DirectX 12 or later compatible, WDDM 2.0 driver
>>"%W11_REPORT%" echo Overall official support verdict: Unavailable - compare the collected model information with official support documentation.

if errorlevel 1 goto ReportWriteFailed
if defined W11_WRITE_FAILED goto ReportWriteFailed

echo.
echo [Done] report.txt created
echo "%W11_REPORT%"
pause
exit /b 0

:QueryWmi
rem Only the fixed GET queries above are passed to this subroutine.
rem FOR /F plus ECHO normalizes WMIC's redirected Unicode output to CMD text.
rem A second, silent GET checks WMIC exit status without mixing its Unicode pipe
rem with a CMD status marker. Both calls are read-only; no temporary file is used.
set "W11_HAS_DATA="
if not exist "%W11_WMIC%" goto WmicMissing
for /f "tokens=1,* delims==" %%A in ('""%W11_WMIC%" %* /value 2^>nul"') do (
    set "W11_VALUE=%%B"
    if defined W11_VALUE set "W11_HAS_DATA=1"
    set "W11_LINE=%%A=%%B"
    call :AppendWmiLine
)
"%W11_WMIC%" %* /value >nul 2>&1
if errorlevel 1 goto QueryUnavailable
if not errorlevel 0 goto QueryUnavailable
if not defined W11_HAS_DATA goto QueryUnavailable
>>"%W11_REPORT%" echo.
exit /b 0

:AppendWmiLine
rem Enable delayed expansion only after capturing the data; never CALL the data.
setlocal EnableDelayedExpansion
>>"!W11_REPORT!" echo(!W11_LINE!
if errorlevel 1 (
    endlocal
    set "W11_WRITE_FAILED=1"
    exit /b 0
)
endlocal
exit /b 0

:WmicMissing
>>"%W11_REPORT%" echo Unavailable - the built-in Windows WMIC executable was not found.
>>"%W11_REPORT%" echo.
exit /b 0

:QueryUnavailable
>>"%W11_REPORT%" echo Unavailable - the WMIC query failed or returned no data.
>>"%W11_REPORT%" echo.
exit /b 0

:ExistingReport
echo report.txt already exists. It will not be overwritten or renamed.
echo Delete the existing report.txt yourself, then run this script again.
echo "%W11_REPORT%"
pause
exit /b 1

:ReportWriteFailed
echo [Error] Could not create or write report.txt.
echo Check write permissions for the script folder and available disk space.
echo Administrator elevation and settings changes are not performed.
pause
exit /b 1
