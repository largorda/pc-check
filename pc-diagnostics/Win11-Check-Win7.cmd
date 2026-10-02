@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Windows 7 CMD/WMIC queries only. Report writes use append after an existence check.
rem Save this batch file as CP949 without BOM, with CRLF, for Korean Windows 7.
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
>>"%W11_REPORT%" echo 읽기 전용 조회 결과입니다. 이 파일만 생성하며 설정 변경 명령은 실행하지 않습니다.
>>"%W11_REPORT%" echo 조회 실패 또는 결과가 없으면 "확인 불가"로 기록합니다.
>>"%W11_REPORT%" echo 속성의 빈 값은 정보가 없다는 뜻이며, 해당 기능의 미지원으로 단정하지 않습니다.
>>"%W11_REPORT%" echo 용량의 Size/Capacity/TotalPhysicalMemory 단위는 bytes입니다.
>>"%W11_REPORT%" echo 이 보고서만으로 CPU 공식 지원이나 Windows 11 설치 가능 여부를 자동 확정하지 않습니다.

echo [1/8] Windows 정보 확인 중...
>>"%W11_REPORT%" echo.
>>"%W11_REPORT%" echo ===== [1/8] Windows =====
call :QueryWmi os get Caption,Version,BuildNumber,OSArchitecture,CSDVersion,ServicePackMajorVersion,ServicePackMinorVersion,SystemDrive

echo [2/8] CPU 확인 중...
>>"%W11_REPORT%" echo ===== [2/8] CPU =====
call :QueryWmi cpu get Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,DataWidth,AddressWidth,Architecture,MaxClockSpeed
>>"%W11_REPORT%" echo CPU 세대 및 Microsoft 공식 지원 여부: 확인 불가 - 정확한 모델의 제조사 사양과 Microsoft 목록 대조 필요
>>"%W11_REPORT%" echo DataWidth는 CPU 비트 수, AddressWidth는 현재 OS 주소 폭입니다. 둘은 다를 수 있습니다.
>>"%W11_REPORT%" echo MaxClockSpeed 단위는 MHz입니다. 64비트/클럭/코어 조건만으로 공식 지원 CPU가 되지는 않습니다.

echo [3/8] PC, 메인보드 및 BIOS 확인 중...
>>"%W11_REPORT%" echo ===== [3/8] PC / Mainboard / BIOS =====
>>"%W11_REPORT%" echo [PC]
call :QueryWmi computersystem get Manufacturer,Model,SystemType
>>"%W11_REPORT%" echo [Mainboard]
call :QueryWmi baseboard get Manufacturer,Product,Version
>>"%W11_REPORT%" echo [BIOS]
call :QueryWmi bios get Manufacturer,SMBIOSBIOSVersion,ReleaseDate
>>"%W11_REPORT%" echo BIOS 날짜는 WMI 원본 날짜 문자열입니다. 예: YYYYMMDDhhmmss...
>>"%W11_REPORT%" echo 현재 UEFI/Legacy 부팅 모드: 확인 불가 - Windows 7 WMIC만으로 확정하지 않습니다.
>>"%W11_REPORT%" echo UEFI 지원 및 BIOS 업데이트 가능성: 확인 불가 - 정확한 PC/보드 모델의 공식 문서 필요

echo [4/8] RAM 확인 중...
>>"%W11_REPORT%" echo ===== [4/8] RAM =====
>>"%W11_REPORT%" echo [System-reported physical memory]
call :QueryWmi computersystem get TotalPhysicalMemory
>>"%W11_REPORT%" echo [Memory modules]
call :QueryWmi memorychip get BankLabel,DeviceLocator,Capacity,Manufacturer,PartNumber,Speed
>>"%W11_REPORT%" echo [Memory arrays]
call :QueryWmi path Win32_PhysicalMemoryArray get MemoryDevices,MaxCapacity
>>"%W11_REPORT%" echo 설치된 RAM은 모듈별 Capacity 합계와 대조하십시오.
>>"%W11_REPORT%" echo TotalPhysicalMemory는 예약 메모리/32비트 OS 제한으로 설치 총량보다 작을 수 있습니다.
>>"%W11_REPORT%" echo MemoryDevices는 WMI가 보고한 배열별 슬롯 수이며 MaxCapacity 단위는 KB입니다.

echo [5/8] 저장장치 확인 중...
>>"%W11_REPORT%" echo ===== [5/8] Storage devices =====
call :QueryWmi diskdrive get Index,Model,Size,InterfaceType,MediaType
>>"%W11_REPORT%" echo HDD/SSD 종류: 확인 불가 - 저장장치 모델의 제조사 사양으로 확인하십시오.
>>"%W11_REPORT%" echo MediaType의 Fixed hard disk media는 HDD/SSD를 구분하지 않습니다.
>>"%W11_REPORT%" echo Windows 11의 최소 저장 용량은 64 GB이며 SSD 자체가 필수 조건은 아닙니다.

echo [6/8] 디스크 파티션 확인 중...
>>"%W11_REPORT%" echo ===== [6/8] Partitions and local volumes =====
>>"%W11_REPORT%" echo [Partitions]
call :QueryWmi partition get DiskIndex,Index,Name,Type,Size,BootPartition,Bootable
>>"%W11_REPORT%" echo [Fixed local volumes only]
call :QueryWmi logicaldisk where "DriveType=3" get DeviceID,FileSystem,Size,FreeSpace
>>"%W11_REPORT%" echo [Logical disk to partition associations]
call :QueryWmi path Win32_LogicalDiskToPartition get Antecedent,Dependent
>>"%W11_REPORT%" echo 시스템 디스크가 Disk 0 또는 C:라고 가정하지 마십시오. Windows SystemDrive와 연관 관계를 대조하십시오.
>>"%W11_REPORT%" echo MBR/GPT 확정 판정: 확인 불가 - Type 원본값을 기록하며 GPT 표기가 없다고 MBR로 단정하지 않습니다.
>>"%W11_REPORT%" echo 파티션 조회만 수행했으며 파티션/부팅 구성은 변경하지 않습니다.

echo [7/8] 그래픽카드 확인 중...
>>"%W11_REPORT%" echo ===== [7/8] Graphics =====
call :QueryWmi path Win32_VideoController get Name,AdapterCompatibility,AdapterRAM,DriverVersion
>>"%W11_REPORT%" echo AdapterRAM 단위는 bytes이며 32비트 WMI 필드라 4 GiB 이상에서 부정확할 수 있습니다.
>>"%W11_REPORT%" echo DirectX 12 지원 여부: 확인 불가 - GPU 공식 사양과 Windows 11용 드라이버 지원 확인 필요
>>"%W11_REPORT%" echo WDDM 버전: 확인 불가 - 추가 파일을 생성하는 그래픽 진단 도구는 실행하지 않습니다.

echo [8/8] TPM 및 Secure Boot 정보 확인 중...
>>"%W11_REPORT%" echo ===== [8/8] TPM / Secure Boot =====
>>"%W11_REPORT%" echo [TPM WMI properties only]
call :QueryWmi /namespace:\\root\cimv2\security\microsofttpm path Win32_Tpm get SpecVersion,ManufacturerId,ManufacturerVersion,IsEnabled_InitialValue,IsActivated_InitialValue
>>"%W11_REPORT%" echo TPM 버전은 SpecVersion 첫 항목으로 확인하며 ManufacturerVersion은 별도 펌웨어 버전입니다.
>>"%W11_REPORT%" echo TPM 조회 실패는 TPM 부재나 TPM 2.0 미지원의 확정 증거가 아닙니다.
>>"%W11_REPORT%" echo Intel PTT / AMD fTPM 지원 가능성: 확인 불가 - 정확한 PC/보드 모델의 공식 문서 필요
>>"%W11_REPORT%" echo Secure Boot 지원 및 현재 활성화 여부: 확인 불가 - Windows 7 WMIC의 안전한 표준 조회 항목이 없습니다.
>>"%W11_REPORT%" echo UEFI 지원만으로 Secure Boot 지원을 확정하지 않으며 레지스트리/펌웨어 설정은 변경하지 않습니다.
>>"%W11_REPORT%" echo.
>>"%W11_REPORT%" echo ===== Windows 11 comparison checklist =====
>>"%W11_REPORT%" echo CPU: Microsoft 공식 지원 64비트 CPU/SoC, 1 GHz 이상, 2코어 이상
>>"%W11_REPORT%" echo RAM: 4 GB 이상
>>"%W11_REPORT%" echo Storage: 64 GB 이상 및 설치/업데이트용 여유 공간
>>"%W11_REPORT%" echo Firmware: UEFI, Secure Boot 가능 / TPM: 2.0
>>"%W11_REPORT%" echo Graphics: DirectX 12 이상 호환, WDDM 2.0 드라이버
>>"%W11_REPORT%" echo 공식 지원 종합 판정: 확인 불가 - 수집한 모델 정보와 공식 지원 자료를 대조해야 합니다.

if errorlevel 1 goto ReportWriteFailed
if defined W11_WRITE_FAILED goto ReportWriteFailed

echo.
echo [완료] report.txt 생성 완료
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
>>"%W11_REPORT%" echo 확인 불가 - Windows 기본 WMIC 실행 파일을 찾지 못했습니다.
>>"%W11_REPORT%" echo.
exit /b 0

:QueryUnavailable
>>"%W11_REPORT%" echo 확인 불가 - WMIC 조회 실패 또는 조회 결과가 없습니다.
>>"%W11_REPORT%" echo.
exit /b 0

:ExistingReport
echo 기존 report.txt가 있습니다. 덮어쓰거나 이름을 변경하지 않습니다.
echo 해당 파일을 직접 삭제한 뒤 다시 실행하십시오.
echo "%W11_REPORT%"
pause
exit /b 1

:ReportWriteFailed
echo [오류] report.txt 생성 또는 기록에 실패했습니다.
echo 파일이 있는 폴더의 쓰기 권한과 사용 가능한 공간을 확인하십시오.
echo 관리자 권한 승격이나 설정 변경은 수행하지 않습니다.
pause
exit /b 1
