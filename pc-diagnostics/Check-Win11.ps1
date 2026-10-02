# Query-only diagnostics, written for Windows 7 / Windows PowerShell 2.0.
# Explicit write: atomic creation of one report.txt in an EXISTING local directory.
# No claim that Windows/WMI creates no logs, cache files or other incidental state.
# No external executable, runtime compilation, firmware/disk mutation or WMI method.
param([string]$ReportPath = '')

$ErrorActionPreference = 'Stop'
$unknown = '확인 불가'
$script:Rows = New-Object System.Collections.ArrayList
$script:Problems = New-Object System.Collections.ArrayList

function Add-Row([int]$Id, [string]$Item, $Value, [string]$Note) {
    $text = [string]$Value
    if ([string]::IsNullOrEmpty($text.Trim())) { $text = $unknown }
    $row = New-Object PSObject -Property @{ Id=$Id; Item=$Item; Value=$text; Note=$Note }
    [void]$script:Rows.Add($row)
}

function Read-Wmi([string]$Class, [string]$Namespace = 'root\cimv2') {
    if (-not $script:WmiReady) { return }
    try { Get-WmiObject -Namespace $Namespace -Class $Class -ErrorAction Stop }
    catch { [void]$script:Problems.Add($Class + ': ' + $_.Exception.Message) }
}

function Join-Property($Objects, [string]$Property) {
    $values = @($Objects | ForEach-Object { [string]$_.PSObject.Properties[$Property].Value } |
        Where-Object { -not [string]::IsNullOrEmpty($_) })
    if ($values.Count -eq 0) { return $unknown }
    return ($values -join '; ')
}

function Size-Text($Bytes) {
    if ($null -eq $Bytes -or [string]::IsNullOrEmpty([string]$Bytes)) { return $unknown }
    return ('{0:N2} GiB / {1:N2} GB ({2} bytes)' -f ([double]$Bytes / 1GB),
        ([double]$Bytes / 1000000000), $Bytes)
}

# Resolve the report target without creating directories or trusting provider paths.
if ([string]::IsNullOrEmpty($ReportPath)) {
    $scriptFile = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrEmpty($scriptFile)) { throw 'A script file path is required.' }
    $ReportPath = [IO.Path]::Combine([IO.Path]::GetDirectoryName($scriptFile), 'report.txt')
}
if (-not [IO.Path]::IsPathRooted($ReportPath)) { throw 'ReportPath must be an absolute local path.' }
if ($ReportPath.StartsWith('\\') -or $ReportPath -match '^[\\/]{2}') {
    throw 'Network and device paths are not accepted.'
}
$ReportPath = [IO.Path]::GetFullPath($ReportPath)
if ([IO.Path]::GetFileName($ReportPath) -cne 'report.txt') {
    throw 'Only a new file named report.txt is permitted.'
}
$parent = [IO.Path]::GetDirectoryName($ReportPath)
if (-not [IO.Directory]::Exists($parent)) { throw 'The existing report directory was not found.' }
$drive = New-Object System.IO.DriveInfo -ArgumentList ([IO.Path]::GetPathRoot($ReportPath))
if ($drive.DriveType -eq [IO.DriveType]::Network) {
    throw 'Mapped network drives are not accepted.'
}
# Reject links/junctions before opening. CreateNew remains the no-overwrite control.
$cursor = $parent
while (-not [string]::IsNullOrEmpty($cursor)) {
    $attributes = [IO.File]::GetAttributes($cursor)
    if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Report directory links/junctions are not accepted.'
    }
    $next = [IO.Path]::GetDirectoryName($cursor)
    if ($next -eq $cursor) { break }
    $cursor = $next
}

# FileMode.CreateNew fails atomically if ANY file already occupies this path.
# No deletion, rollback, rename, replacement, append or retry is performed.
$reportStream = New-Object System.IO.FileStream -ArgumentList @(
    $ReportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None) -ErrorAction Stop
$reportWriter = $null
try {
    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $true
    $reportWriter = New-Object System.IO.StreamWriter -ArgumentList @($reportStream, $encoding) -ErrorAction Stop

    # Avoid querying WMI when its service is stopped or its state cannot be read.
    # No service-start/configuration command exists. This cannot eliminate OS/provider logging.
    $script:WmiReady = $false
    try {
        $wmiService = Get-Service -Name 'Winmgmt' -ErrorAction Stop
        if ([string]$wmiService.Status -eq 'Running') { $script:WmiReady = $true }
        else { [void]$script:Problems.Add('WMI service is not running; all WMI queries skipped.') }
    } catch { [void]$script:Problems.Add('WMI service state unavailable; all WMI queries skipped.') }

    $cs = @(Read-Wmi 'Win32_ComputerSystem')
    $boards = @(Read-Wmi 'Win32_BaseBoard')
    $bios = @(Read-Wmi 'Win32_BIOS')
    $cpus = @(Read-Wmi 'Win32_Processor')
    $ram = @(Read-Wmi 'Win32_PhysicalMemory')
    $ramArrays = @(Read-Wmi 'Win32_PhysicalMemoryArray')
    $disks = @(Read-Wmi 'Win32_DiskDrive')
    $partitions = @(Read-Wmi 'Win32_DiskPartition')
    $gpus = @(Read-Wmi 'Win32_VideoController')
    $os = @(Read-Wmi 'Win32_OperatingSystem')
    $tpm = @(Read-Wmi 'Win32_Tpm' 'root\cimv2\security\microsofttpm')

    Add-Row 1 'PC 제조사 및 모델' ((Join-Property $cs 'Manufacturer') + ' / ' + (Join-Property $cs 'Model')) 'SMBIOS/WMI 보고값'
    Add-Row 2 '메인보드 제조사' (Join-Property $boards 'Manufacturer') 'OEM 제품은 PC 모델과 함께 확인'
    Add-Row 3 '메인보드 정확한 모델명' (Join-Property $boards 'Product') '제조사 지원 페이지와 대조 필요'
    Add-Row 4 '메인보드 버전' (Join-Property $boards 'Version') 'WMI 값이 비어 있거나 일반 문자열이면 PCB 리비전 확인 불가'
    Add-Row 5 'BIOS 제조사' (Join-Property $bios 'Manufacturer') '읽기 전용'
    Add-Row 6 'BIOS 버전' (Join-Property $bios 'SMBIOSBIOSVersion') '업데이트하지 않음'
    $dates = @($bios | ForEach-Object {
        try { [System.Management.ManagementDateTimeConverter]::ToDateTime($_.ReleaseDate).ToString('yyyy-MM-dd') }
        catch { [string]$_.ReleaseDate }
    })
    Add-Row 7 'BIOS 날짜' ($dates -join '; ') 'WMI ReleaseDate'

    $bootMode = $unknown
    Add-Row 8 '현재 BIOS/UEFI 부팅 모드' $bootMode '파일 생성 제한을 위해 동적 컴파일/외부 부팅 도구 실행을 생략. Legacy 부팅만으로 UEFI 미지원 판정 불가'
    Add-Row 9 'CPU 제조사' (Join-Property $cpus 'Manufacturer') '각 CPU 패키지의 보고값'
    Add-Row 10 'CPU 정확한 모델명' (Join-Property $cpus 'Name') 'Microsoft 공식 지원 목록 및 CPU 제조사 공식 사양과 정확히 대조 필요'
    Add-Row 11 'CPU 세대' $unknown '모델명 숫자로 추측하지 않음. Intel/AMD 공식 제품 사양으로 확인 필요'
    Add-Row 12 'CPU 코어 수' (Join-Property $cpus 'NumberOfCores') '여러 CPU이면 패키지별 값'
    Add-Row 13 'CPU 스레드 수' (Join-Property $cpus 'NumberOfLogicalProcessors') '현재 OS에서 보이는 논리 프로세서 수'
    $architectureNames = @{ 0='x86 (32-bit)'; 5='ARM'; 6='IA64 (Windows 11 지원 대상 아님)'; 9='x64 (64-bit)'; 12='ARM64 (64-bit)' }
    $arch = @($cpus | ForEach-Object {
        $label = $unknown
        if ($null -ne $_.Architecture -and [string]$_.Architecture -ne '') {
            $code = [int]$_.Architecture
            if ($architectureNames.ContainsKey($code)) { $label = $architectureNames[$code] }
        }
        'Architecture=' + $label + ', DataWidth=' + $_.DataWidth + ', AddressWidth=' + $_.AddressWidth
    })
    Add-Row 14 'CPU 아키텍처' ($arch -join '; ') 'DataWidth는 CPU 폭, AddressWidth는 현재 OS 주소 폭. Windows 32비트와 CPU 64비트는 구별'
    $ramTotal = $null; $ramInstalledVerified = $false
    $ramSource = 'Win32_ComputerSystem 보고값. 예약 메모리/32비트 OS 제한으로 설치 총량보다 작을 수 있음'
    if ($cs.Count -gt 0) { $ramTotal = $cs[0].TotalPhysicalMemory }
    if ($ram.Count -gt 0 -and @($ram | Where-Object { $null -eq $_.Capacity -or [double]$_.Capacity -le 0 }).Count -eq 0) {
        $ramTotal = ($ram | Measure-Object -Property Capacity -Sum).Sum
        $ramInstalledVerified = $true
        $ramSource = 'Win32_PhysicalMemory 모듈 Capacity 합계 (설치된 RAM); OS 보고값=' + (Join-Property $cs 'TotalPhysicalMemory') + ' bytes'
    }
    Add-Row 15 '설치된 RAM 총 용량' (Size-Text $ramTotal) $ramSource
    $moduleDescriptions = @($ram | ForEach-Object {
        'Slot=' + $_.DeviceLocator + ', Bank=' + $_.BankLabel + ', Capacity=' + (Size-Text $_.Capacity) +
        ', Manufacturer=' + $_.Manufacturer + ', PartNumber=' + $_.PartNumber + ', SpeedMHz=' + $_.Speed
    })
    $slotCount = Join-Property $ramArrays 'MemoryDevices'
    Add-Row 16 'RAM 구성 및 슬롯별 용량' ($moduleDescriptions -join ' | ') ('WMI 장착 모듈=' + $ram.Count + ', 배열별 총 슬롯 보고값=' + $slotCount + '; 빈 슬롯/최대 용량은 보드 문서 확인')

    $diskDetails = New-Object System.Collections.ArrayList
    foreach ($disk in $disks) {
        $style = $unknown
        $partitionTypes = @($partitions | Where-Object { [int]$_.DiskIndex -eq [int]$disk.Index } |
            ForEach-Object { [string]$_.Type })
        # Only a positive GPT label is used; absence does NOT prove MBR.
        if (@($partitionTypes | Where-Object { $_ -match '^GPT:' }).Count -gt 0) {
            $style = 'GPT (WMI partition Type reports GPT:)'
        }
        [void]$diskDetails.Add((New-Object PSObject -Property @{
            Index=$disk.Index; Model=$disk.Model; SizeBytes=$disk.Size; Interface=$disk.InterfaceType;
            MediaType=$disk.MediaType; PartitionStyle=$style; PartitionTypes=($partitionTypes -join '; ')
        }))
    }
    Add-Row 17 '저장장치 모델명' (($diskDetails | ForEach-Object { 'Disk ' + $_.Index + ': ' + $_.Model }) -join ' | ') '디스크 번호를 함께 기록'
    Add-Row 18 'HDD 또는 SSD 여부' (($diskDetails | ForEach-Object {
        'Disk ' + $_.Index + ': ' + $unknown + '; MediaType=' + $_.MediaType
    }) -join ' | ') 'Fixed hard disk media는 HDD/SSD 구분값이 아님. 모델의 제조사 사양으로 확정. 디스크 IOCTL/컴파일을 실행하지 않음'
    Add-Row 19 '저장장치 용량' (($diskDetails | ForEach-Object { 'Disk ' + $_.Index + ': ' + (Size-Text $_.SizeBytes) }) -join ' | ') '논리 볼륨 여유 공간은 별도 기록'

    $osDiskIndexes = @(); $systemDiskIndexes = @(); $osDrive = $unknown
    if ($os.Count -gt 0 -and $os[0].SystemDrive) { $osDrive = [string]$os[0].SystemDrive }
    try {
        if ($script:WmiReady -and $osDrive -match '^[A-Za-z]:$') {
            $query = "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$osDrive'} WHERE AssocClass=Win32_LogicalDiskToPartition"
            $osParts = @(Get-WmiObject -Query $query -ErrorAction Stop)
            $osDiskIndexes = @($osParts | ForEach-Object { [int]$_.DiskIndex } | Sort-Object -Unique)
        }
    } catch { [void]$script:Problems.Add('Windows volume to disk mapping: ' + $_.Exception.Message) }
    foreach ($partition in $partitions) {
        if ($partition.BootPartition -eq $true) { $systemDiskIndexes += [int]$partition.DiskIndex }
    }
    $systemDiskIndexes = @($systemDiskIndexes | Sort-Object -Unique)
    $mapDescriptions = New-Object System.Collections.ArrayList
    foreach ($index in $osDiskIndexes) {
        $item = @($diskDetails | Where-Object { [int]$_.Index -eq $index })
        if ($item.Count -gt 0) { [void]$mapDescriptions.Add('Windows volume ' + $osDrive + ': Disk ' + $index + ' = ' + $item[0].PartitionStyle) }
    }
    foreach ($index in $systemDiskIndexes) {
        $item = @($diskDetails | Where-Object { [int]$_.Index -eq $index })
        if ($item.Count -gt 0) { [void]$mapDescriptions.Add('BootPartition=True disk ' + $index + ' = ' + $item[0].PartitionStyle) }
    }
    Add-Row 20 '시스템 디스크 MBR/GPT' ($mapDescriptions -join ' | ') '디스크 0 또는 C:라고 가정하지 않음. Windows 볼륨/부팅 파티션 디스크를 구분. GPT만으로 UEFI 부팅을 확정하지 않음'
    Add-Row 21 '그래픽카드 제조사 및 모델' (($gpus | ForEach-Object { $_.AdapterCompatibility + ' / ' + $_.Name }) -join ' | ') 'Windows가 인식한 각 어댑터'

    $videoMemory = @($gpus | ForEach-Object { $_.Name + ': WMI AdapterRAM=' + (Size-Text $_.AdapterRAM) })
    Add-Row 22 '그래픽 메모리' ($videoMemory -join ' | ') 'WMI AdapterRAM은 32비트 필드로 4 GiB 이상에서 부정확할 수 있음. 추가 파일을 만드는 dxdiag는 실행하지 않음'
    Add-Row 23 'DirectX 지원 정보' $unknown '추가 파일/외부 프로그램 실행을 피하기 위해 dxdiag 생략. GPU 공식 사양 확인 필요'
    Add-Row 24 'WDDM 버전' $unknown '추가 파일/외부 프로그램 실행을 피하기 위해 dxdiag 생략. 드라이버 공식 자료 확인 필요'

    $tpmExistence = $unknown
    if ($tpm.Count -gt 0) { $tpmExistence = 'WMI에서 TPM 장치 조회됨' }
    Add-Row 25 'TPM 존재 여부' $tpmExistence 'WMI 조회 실패/빈 결과는 TPM 부재 증거가 아님. 비활성화/드라이버/Windows 7 제한 가능'
    Add-Row 26 'TPM 버전' (Join-Property $tpm 'SpecVersion') 'SpecVersion 첫 항목이 TPM 규격 버전. 제조사 펌웨어 버전과 구별'
    $tpm2 = $unknown
    if (@($tpm | Where-Object { $_.SpecVersion -match '^\s*2\.0\s*(,|$)' }).Count -gt 0) {
        $tpm2 = '조회된 TPM 규격 2.0 확인'
    } elseif (@($tpm | Where-Object { $_.SpecVersion -match '^\s*1\.2\s*(,|$)' }).Count -gt 0) {
        $tpm2 = '현재 조회된 TPM은 1.2; TPM 2.0 추가/전환 가능성은 확인 불가'
    }
    Add-Row 27 'TPM 2.0 지원 여부' $tpm2 '모든 TPM 설정/초기화/활성화 메서드를 호출하지 않음'
    Add-Row 28 'Intel PTT / AMD fTPM 지원 가능성' $unknown '정확한 PC/메인보드 모델, 리비전, CPU와 제조사 BIOS 문서 필요'
    $sbState = $unknown; $sbSupport = $unknown
    $sbKey = $null
    try {
        # writable=false explicitly requests a read-only registry handle.
        $sbKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            'SYSTEM\CurrentControlSet\Control\SecureBoot\State', $false)
        if ($null -ne $sbKey) {
            $value = $sbKey.GetValue('UEFISecureBootEnabled', $null)
            if ($null -ne $value -and [int]$value -eq 1) {
                $sbState = '활성화 보고값 1 (read-only registry)'
                $sbSupport = '활성화 보고값 존재; 현재 OS/펌웨어와 교차 확인 필요'
            } elseif ($null -ne $value -and [int]$value -eq 0) {
                $sbState = '비활성화 보고값 0 (read-only registry)'
            }
        } else { [void]$script:Problems.Add('Secure Boot key absent; not proof of unsupported firmware.') }
    } catch { [void]$script:Problems.Add('Secure Boot registry read unavailable: ' + $_.Exception.Message) }
    finally { if ($null -ne $sbKey) { $sbKey.Close() } }
    Add-Row 29 'Secure Boot 지원 여부' $sbSupport 'Windows 7 조회 한계. UEFI 지원만으로 Secure Boot 지원을 확정하지 않음'
    Add-Row 30 '현재 Secure Boot 활성화 여부' $sbState '키가 없으면 확인 불가. 설정 변경하지 않음'
    Add-Row 31 '현재 Windows 에디션' (Join-Property $os 'Caption') ('OS Version=' + (Join-Property $os 'Version') + '; Build=' + (Join-Property $os 'BuildNumber'))
    Add-Row 32 'Service Pack 상태' (Join-Property $os 'CSDVersion') ('SP Major=' + (Join-Property $os 'ServicePackMajorVersion') + ', Minor=' + (Join-Property $os 'ServicePackMinorVersion') + '; 0은 미적용')
    Add-Row 33 'Windows 32비트/64비트' (Join-Property $os 'OSArchitecture') 'CPU DataWidth와 구별'

    $comparison = New-Object System.Collections.ArrayList
    function Add-Check([string]$Item, [string]$Current, [string]$Requirement, [string]$Verdict, [string]$Note) {
        [void]$comparison.Add((New-Object PSObject -Property @{
            Item=$Item; Current=$Current; Requirement=$Requirement; Verdict=$Verdict; Note=$Note
        }))
    }
    $cpuBasics = $unknown
    if ($cpus.Count -gt 0) {
        $incomplete = @($cpus | Where-Object { $null -eq $_.DataWidth -or $null -eq $_.NumberOfCores -or $null -eq $_.MaxClockSpeed })
        if ($incomplete.Count -eq 0) {
            $badCpu = @($cpus | Where-Object { $_.DataWidth -lt 64 -or $_.NumberOfCores -lt 2 -or $_.MaxClockSpeed -lt 1000 -or $_.Architecture -eq 6 })
            if ($badCpu.Count -gt 0) { $cpuBasics = '최소 사양 미충족' } else { $cpuBasics = '수치 조건 충족; 공식 CPU 지원은 확인 불가' }
        }
    }
    Add-Check 'CPU' (Join-Property $cpus 'Name') 'Microsoft 공식 지원 64비트 CPU/SoC, 1 GHz 이상, 2코어 이상' $cpuBasics ('MaxClockSpeed(MHz)=' + (Join-Property $cpus 'MaxClockSpeed') + '; 세대와 지원 목록 대조 필요')
    $ramVerdict = $unknown
    if ($null -ne $ramTotal -and [string]$ramTotal -ne '') {
        if ([double]$ramTotal -ge 4GB) { $ramVerdict='충족' }
        elseif ($ramInstalledVerified) { $ramVerdict='미충족' }
    }
    Add-Check 'RAM' (Size-Text $ramTotal) '4 GB 이상' $ramVerdict '추가 RAM은 보드 메모리 규격/최대 용량/슬롯 문서 확인 후 결정'
    Add-Check '저장장치' (($diskDetails | ForEach-Object { 'Disk ' + $_.Index + ': ' + (Size-Text $_.SizeBytes) }) -join ' | ') '64 GB 이상 저장장치' $unknown '설치 대상 디스크를 선택하지 않음. 현재 Windows 볼륨의 용량/여유 공간은 아래 추가 정보 참고. SSD는 필수 아님'
    $uefiVerdict = $unknown
    if ($bootMode -like 'UEFI*') { $uefiVerdict = 'UEFI 부팅 확인' }
    elseif ($bootMode -like 'Legacy*') { $uefiVerdict = '현재 Legacy 부팅; UEFI 지원 가능성은 확인 불가' }
    Add-Check 'UEFI' $bootMode 'UEFI 펌웨어' $uefiVerdict '현재 Legacy 부팅이면 UEFI 지원 가능성은 보드 공식 문서로 확인'
    Add-Check 'Secure Boot' $sbState 'Secure Boot 가능 펌웨어' $unknown '지원 가능성과 현재 활성화는 별도 항목. UEFI 지원만으로 판정하지 않음'
    $tpmVerdict = $unknown
    if ($tpm2 -eq '조회된 TPM 규격 2.0 확인') { $tpmVerdict = 'TPM 2.0 규격 확인; 활성화 상태는 추가 정보 참고' }
    elseif ($tpm2 -like '현재 조회된 TPM은 1.2*') { $tpmVerdict = '현재 조회된 TPM 규격 미충족; 보드의 전환 가능성 확인 불가' }
    Add-Check 'TPM' (Join-Property $tpm 'SpecVersion') 'TPM 2.0' $tpmVerdict $tpm2
    Add-Check '그래픽' (($gpus | ForEach-Object { $_.Name }) -join '; ') 'DirectX 12 이상 호환 그래픽, WDDM 2.0 드라이버' $unknown 'Windows 7 런타임/드라이버만으로 Windows 11 GPU 지원을 확정하지 않음'
    Add-Check '디스플레이' $unknown '720p 이상, 대각선 9인치 초과, 색상 채널당 8비트' $unknown '화면 크기/색심도는 모니터 모델 사양 확인 필요'
    Add-Check 'MBR/GPT' ($mapDescriptions -join ' | ') 'Windows UEFI 부팅을 위한 GPT 시스템 디스크 구성' $unknown 'MBR에서 GPT로 변환하지 않음'
    Add-Check '현재 Windows / 설치 경로' ((Join-Property $os 'Caption') + ' / ' + (Join-Property $os 'OSArchitecture')) 'Windows 11은 64비트. Windows 7에서 직접 인플레이스 업그레이드는 지원되지 않음' '설치 경로 별도 계획 필요' '하드웨어 호환성과 설치/정품 인증 경로는 별개; 유효한 Windows 11 라이선스 확인 필요'

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('Windows 11 query-only diagnostic report - source audit, not a Windows-state guarantee')
    [void]$lines.Add('Collected: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
    [void]$lines.Add('PowerShell: ' + $PSVersionTable.PSVersion.ToString())
    [void]$lines.Add('A-D 판정: 보류. CPU 공식 지원/보드 기능/누락 항목의 외부 확인 후 판단해야 합니다.')
    [void]$lines.Add('스크립트의 명시적 쓰기: report.txt 신규 생성만 허용. OS/WMI의 로그·캐시 등 간접 변경은 검증하지 못했습니다.')
    foreach ($row in $script:Rows) {
        [void]$lines.Add('')
        [void]$lines.Add(('[{0:D2}] {1}: {2}' -f $row.Id, $row.Item, $row.Value))
        [void]$lines.Add('  비고: ' + $row.Note)
    }
    [void]$lines.Add('')
    [void]$lines.Add('Additional evidence (read-only)')
    foreach ($detail in $diskDetails) {
        [void]$lines.Add('Disk ' + $detail.Index + ' WMI partition types: ' + $detail.PartitionTypes)
    }
    foreach ($device in $tpm) {
        [void]$lines.Add('TPM: SpecVersion=' + $device.SpecVersion + '; ManufacturerVersion=' + $device.ManufacturerVersion +
            '; IsEnabled_InitialValue=' + $device.IsEnabled_InitialValue + '; IsActivated_InitialValue=' + $device.IsActivated_InitialValue)
    }
    try {
        if ($script:WmiReady -and $osDrive -match '^[A-Za-z]:$') {
            $volumes = @(Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$osDrive'" -ErrorAction Stop)
            foreach ($volume in $volumes) {
                [void]$lines.Add('Windows volume ' + $osDrive + ': Capacity=' + (Size-Text $volume.Size) + '; Free=' + (Size-Text $volume.FreeSpace))
            }
        }
    } catch { [void]$script:Problems.Add('Windows volume size: ' + $_.Exception.Message) }
    [void]$lines.Add('')
    [void]$lines.Add('항목 | 현재 PC 사양 | Windows 11 요구사항 | 판정 | 비고')
    foreach ($check in $comparison) {
        [void]$lines.Add(($check.Item, $check.Current, $check.Requirement, $check.Verdict, $check.Note -join ' | '))
    }
    [void]$lines.Add('')
    [void]$lines.Add('Missing / failed queries (do not interpret as absent hardware)')
    foreach ($problem in $script:Problems) { [void]$lines.Add([string]$problem) }

    foreach ($line in $lines) { $reportWriter.WriteLine([string]$line) }
    $reportWriter.Flush()
    Write-Host ('Report created: ' + $ReportPath)
    Write-Host 'No other output file is requested by this script. Windows/WMI side effects are not certified.'
} finally {
    if ($null -ne $reportWriter) { $reportWriter.Dispose() }
    $reportStream.Dispose()
}
