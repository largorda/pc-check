@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Built-in Windows 7 queries only. No output parsing or temporary files.
rem ASCII text only, without BOM, with CRLF.
rem report.txt and the original diagnostic scripts are not modified.

set "W11_REPORT2=%~dp0report2.txt"
if exist "%W11_REPORT2%" goto ExistingReport

>>"%W11_REPORT2%" echo Windows 7 hardware diagnostic - raw command output
if errorlevel 1 goto ReportWriteFailed
if not exist "%W11_REPORT2%" goto ReportWriteFailed
>>"%W11_REPORT2%" echo Command output and error messages are recorded without parsing or conversion.

echo [1/12] Running systeminfo...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [1/12] SYSTEMINFO =====
"%SystemRoot%\System32\systeminfo.exe" >>"%W11_REPORT2%" 2>&1

echo [2/12] Checking CPU...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [2/12] CPU =====
"%SystemRoot%\System32\wbem\WMIC.exe" cpu get Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,DataWidth,MaxClockSpeed >>"%W11_REPORT2%" 2>&1

echo [3/12] Checking PC and total RAM...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [3/12] PC / TOTAL RAM =====
"%SystemRoot%\System32\wbem\WMIC.exe" computersystem get Manufacturer,Model,SystemType,TotalPhysicalMemory >>"%W11_REPORT2%" 2>&1

echo [4/12] Checking mainboard...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [4/12] MAINBOARD =====
"%SystemRoot%\System32\wbem\WMIC.exe" baseboard get Manufacturer,Product,Version >>"%W11_REPORT2%" 2>&1

echo [5/12] Checking BIOS...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [5/12] BIOS =====
"%SystemRoot%\System32\wbem\WMIC.exe" bios get Manufacturer,SMBIOSBIOSVersion,ReleaseDate >>"%W11_REPORT2%" 2>&1

echo [6/12] Checking RAM modules...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [6/12] RAM MODULES =====
"%SystemRoot%\System32\wbem\WMIC.exe" memorychip get BankLabel,DeviceLocator,Capacity,Manufacturer,PartNumber,Speed >>"%W11_REPORT2%" 2>&1

echo [7/12] Checking disk drives...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [7/12] DISK DRIVES =====
"%SystemRoot%\System32\wbem\WMIC.exe" diskdrive get Index,Model,Size,InterfaceType,MediaType >>"%W11_REPORT2%" 2>&1

echo [8/12] Checking partitions...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [8/12] PARTITIONS =====
"%SystemRoot%\System32\wbem\WMIC.exe" partition get DiskIndex,Index,Type,Size,BootPartition >>"%W11_REPORT2%" 2>&1

echo [9/12] Checking fixed local volumes...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [9/12] FIXED LOCAL VOLUMES =====
"%SystemRoot%\System32\wbem\WMIC.exe" logicaldisk where "DriveType=3" get DeviceID,FileSystem,Size,FreeSpace >>"%W11_REPORT2%" 2>&1

echo [10/12] Checking graphics...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [10/12] GRAPHICS =====
"%SystemRoot%\System32\wbem\WMIC.exe" path Win32_VideoController get Name,AdapterCompatibility,AdapterRAM,DriverVersion >>"%W11_REPORT2%" 2>&1

echo [11/12] Checking Windows edition and architecture...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [11/12] WINDOWS =====
"%SystemRoot%\System32\wbem\WMIC.exe" os get Caption,Version,BuildNumber,OSArchitecture,CSDVersion >>"%W11_REPORT2%" 2>&1

echo [12/12] Checking TPM...
>>"%W11_REPORT2%" echo.
>>"%W11_REPORT2%" echo ===== [12/12] TPM - OPTIONAL =====
>>"%W11_REPORT2%" echo A failed TPM query does not prove that TPM is absent or unsupported.
"%SystemRoot%\System32\wbem\WMIC.exe" /namespace:\\root\cimv2\security\microsofttpm path Win32_Tpm get SpecVersion,ManufacturerId,ManufacturerVersion,IsEnabled_InitialValue,IsActivated_InitialValue >>"%W11_REPORT2%" 2>&1

echo.
echo [Done] Diagnostic commands finished. Review report2.txt for results and errors.
echo "%W11_REPORT2%"
pause
exit /b 0

:ExistingReport
echo report2.txt already exists. It will not be overwritten or renamed.
echo Delete the existing report2.txt yourself, then run this script again.
echo "%W11_REPORT2%"
pause
exit /b 1

:ReportWriteFailed
echo [Error] Could not create report2.txt in the script folder.
echo Check folder write permissions and available disk space.
pause
exit /b 1
