#Requires -Version 5.1
#
# Launch an Android emulator, wait until it has finished booting, seed the
# Budgetly sample SMS inbox, then start the Flutter app on it.
#
# Windows PowerShell counterpart of run_app_with_samples.sh.
#
# By default every run is a clean start: the app is freshly reinstalled and the
# emulator inbox is emptied before the chosen number of sample messages is loaded.
# Pass -NoClean to keep the current app install and inbox.
#
# Usage (from the repo root, or anywhere with an absolute path):
#   powershell -ExecutionPolicy Bypass -File scripts/sms_samples/run_app_with_samples.ps1 [options] [-- flutter args]
#
# Options (both -Name and --name forms work, case-insensitive):
#   -Avd NAME           AVD to launch (default: $env:BUDGETLY_AVD, else first AVD)
#   -Serial SERIAL      Use an already-running device/emulator
#   -Fixture PATH       Sample inbox JSON (default: app/test/fixtures/sample_inbox.json)
#   -MaxMessages N      Sample messages to load and the app's sync cap (default: 100)
#   -ApiBase URL        API_BASE_URL dart-define
#   -Headless           Launch the emulator without a window
#   -NoApp              Seed messages only; do not start the app
#   -NoSeed             Skip seeding (useful with -NoClean; avoids duplicates)
#   -NoClean            Keep existing app install + inbox instead of a clean start
#   -NoLaunch           Do not launch an emulator; use one that is running
#   -Timeout SECONDS    Boot/launch timeout (default: 300)
#   -StopOnExit         Kill the emulator when this script/flutter run exits
#   -h, -Help           Show this help
#
# Anything after `--` is forwarded to `flutter run`, e.g.
#   ... -- --dart-define=LOG_LEVEL=debug
#
# Examples:
#   powershell -ExecutionPolicy Bypass -File scripts/sms_samples/run_app_with_samples.ps1 -Avd Pixel_9a
#   .\scripts\sms_samples\run_app_with_samples.ps1 -Headless -NoApp

$ErrorActionPreference = 'Continue'

$AppId      = 'com.budgetly.app'
$ScriptDir  = $PSScriptRoot
$RepoRoot   = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$AppDir     = Join-Path $RepoRoot 'app'
$SeedScript = Join-Path $ScriptDir 'seed_emulator.py'
$LogDir     = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }

$Avd            = if ($env:BUDGETLY_AVD) { $env:BUDGETLY_AVD } else { '' }
$SerialExplicit = ''
$Fixture        = Join-Path $RepoRoot 'app\test\fixtures\sample_inbox.json'
$MaxMessages    = 100
$ApiBase        = ''
$Headless       = $false
$NoApp          = $false
$NoSeed         = $false
$NoLaunch       = $false
$NoClean        = $false
$Timeout        = 300
$StopOnExit     = $false
$Passthru       = @()

function Write-Info {
    param([string]$Message)
    Write-Host '[budgetly] ' -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host '[budgetly] ' -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Stop-Script {
    param([string]$Message)
    Write-Host '[budgetly] ' -ForegroundColor Red -NoNewline
    Write-Host $Message
    exit 1
}

$Usage = @'
Launch an Android emulator, wait until it has finished booting, seed the
Budgetly sample SMS inbox, then start the Flutter app on it.

Usage:
  powershell -ExecutionPolicy Bypass -File scripts/sms_samples/run_app_with_samples.ps1 [options] [-- flutter args]

Options:
  -Avd NAME           AVD to launch (default: $env:BUDGETLY_AVD, else first AVD)
  -Serial SERIAL      Use an already-running device/emulator
  -Fixture PATH       Sample inbox JSON (default: app/test/fixtures/sample_inbox.json)
  -MaxMessages N      Sample messages to load and the app's sync cap (default: 100)
  -ApiBase URL        API_BASE_URL dart-define
  -Headless           Launch the emulator without a window
  -NoApp              Seed messages only; do not start the app
  -NoSeed             Skip seeding (useful with -NoClean; avoids duplicates)
  -NoClean            Keep existing app install + inbox instead of a clean start
  -NoLaunch           Do not launch an emulator; use one that is running
  -Timeout SECONDS    Boot/launch timeout (default: 300)
  -StopOnExit         Kill the emulator when this script/flutter run exits
  -h, -Help           Show this help

Anything after `--` is forwarded to `flutter run`, e.g.
  ... -- --dart-define=LOG_LEVEL=debug

Examples:
  powershell -ExecutionPolicy Bypass -File scripts/sms_samples/run_app_with_samples.ps1 -Avd Pixel_9a
  .\scripts\sms_samples\run_app_with_samples.ps1 -Headless -NoApp
'@

# ---- Option parsing --------------------------------------------------------

$script:Argv = @($args)
$script:ArgIndex = 0

function Read-OptionValue {
    param([string]$Option)
    $script:ArgIndex++
    if ($script:ArgIndex -ge $script:Argv.Count) {
        Stop-Script "$Option needs a value."
    }
    return [string]$script:Argv[$script:ArgIndex]
}

while ($script:ArgIndex -lt $script:Argv.Count) {
    $arg = [string]$script:Argv[$script:ArgIndex]

    if ($arg -eq '--') {
        if ($script:ArgIndex + 1 -lt $script:Argv.Count) {
            $Passthru = @($script:Argv[($script:ArgIndex + 1)..($script:Argv.Count - 1)])
        }
        break
    }

    if ($arg -match '^(-h|--help|-help|/\?|-\?)$') {
        Write-Output $Usage
        exit 0
    }

    if ($arg -notmatch '^(--?|/)(.+)$') {
        Stop-Script "Unknown option: $arg (use -- to pass arguments to flutter run)"
    }
    # Accept both bash-style (--max-messages) and PowerShell-style (--MaxMessages,
    # -MaxMessages, /MaxMessages): lowercase and drop separators before matching.
    $name = ($Matches[2] -replace '[-_]', '').ToLowerInvariant()

    switch ($name) {
        'avd'         { $Avd = Read-OptionValue '--avd' }
        'serial'      { $SerialExplicit = Read-OptionValue '--serial' }
        'fixture'     { $Fixture = Read-OptionValue '--fixture' }
        'maxmessages' { $MaxMessages = Read-OptionValue '--max-messages' }
        'apibase'     { $ApiBase = Read-OptionValue '--api-base' }
        'headless'    { $Headless = $true }
        'noapp'       { $NoApp = $true }
        'noseed'      { $NoSeed = $true }
        'noclean'     { $NoClean = $true }
        'nolaunch'    { $NoLaunch = $true }
        'timeout'     { $Timeout = Read-OptionValue '--timeout' }
        'stoponexit'  { $StopOnExit = $true }
        default       { Stop-Script "Unknown option: $arg (use -- to pass arguments to flutter run)" }
    }

    $script:ArgIndex++
}

if ([string]$MaxMessages -notmatch '^\d+$') {
    Stop-Script "--max-messages must be a non-negative integer (got '$MaxMessages')."
}
$MaxMessages = [int]$MaxMessages

if ([string]$Timeout -notmatch '^\d+$' -or [int]$Timeout -le 0) {
    Stop-Script "--timeout must be a positive integer (got '$Timeout')."
}
$Timeout = [int]$Timeout

if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    Stop-Script "Repo root not found: $RepoRoot"
}

# Match the UTF-8 output emitted by the Python seed script and by flutter, so
# characters like the rupee sign are not mangled by the OEM code page.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

# ---- Toolchain resolution --------------------------------------------------

# When this script is started from Git Bash, some Windows environment variables
# that Flutter's native toolchain needs may be missing from the child process.
# Add any that are absent (no-op in a normal PowerShell session).
$missingVars = @{
    'ProgramFiles'     = 'C:\Program Files'
    'ProgramFiles(x86)' = 'C:\Program Files (x86)'
    'ProgramData'      = 'C:\ProgramData'
    'SystemRoot'       = 'C:\Windows'
}
foreach ($entry in $missingVars.GetEnumerator()) {
    if (-not [Environment]::GetEnvironmentVariable($entry.Key)) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
    }
}

function Resolve-Adb {
    if ($env:ADB -and (Test-Path -LiteralPath $env:ADB -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $env:ADB).Path
    }
    $cmd = Get-Command adb -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }

    $candidates = @()
    if ($env:LOCALAPPDATA)   { $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe') }
    if ($env:ANDROID_HOME)   { $candidates += (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe') }
    if ($env:ANDROID_SDK_ROOT) { $candidates += (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe') }
    if ($env:USERPROFILE)    { $candidates += (Join-Path $env:USERPROFILE 'Android\Sdk\platform-tools\adb.exe') }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    return $null
}

function Resolve-EmulatorBin {
    $cmd = Get-Command emulator -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }

    $candidates = @()
    if ($env:ANDROID_HOME)    { $candidates += (Join-Path $env:ANDROID_HOME 'emulator\emulator.exe') }
    if ($env:ANDROID_SDK_ROOT) { $candidates += (Join-Path $env:ANDROID_SDK_ROOT 'emulator\emulator.exe') }
    if ($env:LOCALAPPDATA)    { $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\emulator\emulator.exe') }
    if ($env:USERPROFILE)     { $candidates += (Join-Path $env:USERPROFILE 'Android\Sdk\emulator\emulator.exe') }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    return $null
}

function Resolve-Python {
    $candidates = @()
    if ($env:PYTHON) { $candidates += ,@($env:PYTHON) }
    $candidates += ,@('python3')
    $candidates += ,@('python')
    $candidates += ,@('py', '-3')

    foreach ($candidate in $candidates) {
        $exe = $candidate[0]
        $prefix = @()
        if ($candidate.Count -gt 1) { $prefix = @($candidate[1..($candidate.Count - 1)]) }

        if (-not (Get-Command $exe -CommandType Application -ErrorAction SilentlyContinue)) { continue }

        # Check the exit code only: PowerShell 5.1 strips embedded double quotes
        # from native arguments, so a `print("...")` probe arrives at Python
        # mangled. This rejects Python 2 and the Microsoft Store
        # app-execution-alias stubs (which exit 9009).
        & $exe @prefix -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' 2>$null
        if ($LASTEXITCODE -eq 0) { return $candidate }
    }
    return $null
}

$script:Adb = Resolve-Adb
if (-not $script:Adb) { Stop-Script 'adb not found. Add Android platform-tools to PATH.' }

# The Python seeder shells out to a bare `adb`, so make sure the adb we resolved
# is the one child processes find.
$adbDir = Split-Path -Parent $script:Adb
if ($adbDir -and (($env:Path -split ';') -notcontains $adbDir)) {
    $env:Path = $adbDir + ';' + $env:Path
}

$flutterCommand = Get-Command flutter -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$FlutterExe = if ($flutterCommand) { $flutterCommand.Source } else { '' }

# ---- Emulator helpers ------------------------------------------------------

function Get-EmulatorSerials {
    # Without -IncludeOffline, only emulators whose adb link is usable
    # (state == "device") are returned.
    param([switch]$IncludeOffline)
    $result = @()
    $lines = & $script:Adb devices 2>$null
    foreach ($line in $lines) {
        if ($line -match '^(emulator-\d+)\s+(\S+)') {
            if ($IncludeOffline -or $Matches[2] -eq 'device') { $result += $Matches[1] }
        }
    }
    return $result
}

function Get-AvdName {
    if ($Avd) { return $Avd }

    # `emulator -list-avds` prints plain names; preferred over parsing
    # `flutter emulators`, whose bullet-separated table depends on the console
    # code page.
    $emulatorBin = Resolve-EmulatorBin
    if ($emulatorBin) {
        $names = @(& $emulatorBin -list-avds 2>$null | Where-Object { $_ -and $_.Trim() })
        if ($names.Count -gt 0) { return ([string]$names[0]).Trim() }
    }

    if ($FlutterExe) {
        foreach ($line in @(& $FlutterExe emulators 2>$null)) {
            $id = ($line -split ([char]0x2022))[0].Trim()
            if ($id -and $id -ne 'Id' -and $id -notmatch 'available emulators' -and $id -notmatch '^-+$') {
                return $id
            }
        }
    }
    return ''
}

# ---- Emulator selection / launch -------------------------------------------

$script:Serial = ''
$script:StopOnExit = $StopOnExit

function Invoke-Cleanup {
    if ($script:StopOnExit -and $script:Serial) {
        Write-Info "Stopping emulator $script:Serial ..."
        & $script:Adb -s $script:Serial emu kill 2>$null | Out-Null
    }
}

$FlutterExit = 0
$EmulatorLog = Join-Path $LogDir 'budgetly-emulator.log'

try {
    if ($SerialExplicit) {
        $script:Serial = $SerialExplicit
        Write-Info "Using device $script:Serial (launch skipped)."
    }
    elseif ($NoLaunch) {
        $running = @(Get-EmulatorSerials)
        if ($running.Count -eq 0) { Stop-Script '--no-launch given but no emulator is running.' }
        $script:Serial = $running[0]
        Write-Info "Using running emulator $script:Serial."
    }
    else {
        $Avd = Get-AvdName
        if (-not $Avd) {
            Stop-Script "No AVD selected. Pass --avd <name> or create one with 'flutter emulators --create'."
        }

        # If an emulator already running this AVD is up, reuse it -- unless a
        # clean start is requested, in which case it must be relaunched so its
        # data can be wiped (a running instance can't be wiped).
        foreach ($runningSerial in @(Get-EmulatorSerials)) {
            $avdNameOut = & $script:Adb -s $runningSerial emu avd name 2>$null
            if (($avdNameOut -join ' ') -match [regex]::Escape($Avd)) {
                if ($NoClean) {
                    $script:Serial = $runningSerial
                    Write-Info "AVD '$Avd' is already running as $script:Serial; reusing it."
                }
                else {
                    Write-Info "Clean start: stopping already-running $Avd ($runningSerial) so it can relaunch wiped."
                    & $script:Adb -s $runningSerial emu kill 2>$null | Out-Null
                    Start-Sleep -Seconds 3  # let the old instance deregister from adb
                }
                break
            }
        }

        if (-not $script:Serial) {
            $emulatorBin = Resolve-EmulatorBin
            if (-not $emulatorBin) { Stop-Script 'Could not find the emulator binary.' }

            $before = @(Get-EmulatorSerials -IncludeOffline)

            $emuArgs = @('-avd', $Avd)
            if ($Headless) {
                Write-Info "Launching emulator '$Avd' (headless) ..."
                $emuArgs += @('-no-window', '-no-audio', '-no-boot-anim', '-no-snapshot')
            }
            else {
                # Launch directly so we can disable snapshot restore/save: a
                # restored snapshot is what leaves an emulator wedged at
                # "offline" in adb.
                Write-Info "Launching emulator '$Avd' (windowed, fresh boot) ..."
                $emuArgs += @('-no-snapshot-load', '-no-snapshot-save')
            }
            if (-not $NoClean) {
                # The telephony provider on this AVD's user build refuses content
                # delete, so -wipe-data is the only reliable way to empty the
                # inbox (and it also gives the app a genuinely fresh install).
                $emuArgs += '-wipe-data'
                Write-Info 'Clean start: AVD data will be wiped (-wipe-data).'
            }

            # Start-Process cannot send stdout and stderr to the same file.
            $emuArgsQuoted = @($emuArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } })
            try {
                Start-Process -FilePath $emulatorBin `
                    -ArgumentList $emuArgsQuoted `
                    -RedirectStandardOutput $EmulatorLog `
                    -RedirectStandardError (Join-Path $LogDir 'budgetly-emulator.err.log') `
                    -ErrorAction Stop | Out-Null
            }
            catch {
                Stop-Script "Failed to launch the emulator: $($_.Exception.Message)"
            }

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            while ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
                foreach ($candidate in @(Get-EmulatorSerials -IncludeOffline)) {
                    if ($before -notcontains $candidate) {
                        $script:Serial = $candidate
                        break
                    }
                }
                if ($script:Serial) { break }
                Start-Sleep -Seconds 2
            }
            if (-not $script:Serial) {
                $any = @(Get-EmulatorSerials -IncludeOffline)
                if ($any.Count -gt 0) { $script:Serial = $any[0] }
            }
            if (-not $script:Serial) {
                Stop-Script "Emulator did not appear within ${Timeout}s (log: $EmulatorLog)."
            }
            Write-Info "Emulator is $script:Serial."
        }
    }

    # ---- Wait for boot -----------------------------------------------------

    Write-Info "Waiting for $script:Serial to come online and finish booting (timeout ${Timeout}s) ..."
    $booted = ''
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
        $booted = (& $script:Adb -s $script:Serial shell getprop sys.boot_completed 2>$null | Out-String).Trim()
        if ($booted -eq '1') { break }
        Start-Sleep -Seconds 2
    }
    if ($booted -ne '1') { Stop-Script "Timed out waiting for $script:Serial to boot." }
    Start-Sleep -Seconds 2
    Write-Info 'Boot complete.'

    # ---- Clean start (default) ---------------------------------------------

    if ($NoClean) {
        Write-Info 'Keeping existing app install and inbox (--no-clean).'
    }
    else {
        Write-Info "Clean start: ensuring $AppId is uninstalled and the inbox is empty ..."
        # Fresh install: remove the app so `flutter run` installs it from scratch.
        & $script:Adb -s $script:Serial uninstall $AppId 2>$null | Out-Null
        # Empty the SMS provider so each run seeds exactly MaxMessages, never more.
        & $script:Adb -s $script:Serial shell content delete --uri 'content://sms/' 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            & $script:Adb -s $script:Serial shell content delete --uri 'content://sms/' --where '_id > 0' 2>$null | Out-Null
        }
        $rows = @(& $script:Adb -s $script:Serial shell content query --uri 'content://sms/' --projection '_id' 2>$null)
        $remaining = @($rows | Where-Object { $_ -match '^Row:' }).Count
        if ($remaining -ne 0) {
            Write-Warn "Inbox not fully cleared ($remaining row(s) remain); seeded messages may duplicate."
        }
    }

    # ---- Load sample messages ----------------------------------------------

    if ($NoSeed) {
        Write-Info 'Skipping message seeding (--no-seed).'
    }
    else {
        if (-not (Test-Path -LiteralPath $Fixture -PathType Leaf)) {
            Stop-Script "Fixture not found: $Fixture"
        }
        # @(...) keeps a single-element result (one exe path) from unrolling
        # into a bare string, which would make $python[0] its first character.
        $python = @(Resolve-Python)
        if ($python.Count -eq 0 -or -not $python[0]) {
            Stop-Script 'python3 not found (needed to seed messages).'
        }

        $pythonExe = [string]$python[0]
        $pythonPrefix = @()
        if ($python.Count -gt 1) { $pythonPrefix = @($python[1..($python.Count - 1)]) }

        $displayFixture = $Fixture
        if ($displayFixture.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $displayFixture = $displayFixture.Substring($RepoRoot.Length).TrimStart([char[]]@('\', '/'))
        }
        Write-Info "Loading $MaxMessages message(s) from $displayFixture ..."
        try {
            & $pythonExe @pythonPrefix $SeedScript --fixture $Fixture --serial $script:Serial --limit $MaxMessages
            $seedExit = $LASTEXITCODE
        }
        catch {
            Stop-Script "Failed to run $pythonExe`: $($_.Exception.Message)"
        }
        if ($seedExit -ne 0) { Stop-Script "Seeding failed (exit $seedExit)." }
    }

    # Best-effort: auto-grant SMS permissions if the app is already installed.
    # A clean start uninstalled it, so `flutter run` reinstalls and the app asks
    # for SMS access on screen -- accept the prompt there.
    $packagePath = @(& $script:Adb -s $script:Serial shell pm path $AppId 2>$null)
    if ($LASTEXITCODE -eq 0 -and $packagePath.Count -gt 0) {
        & $script:Adb -s $script:Serial shell pm grant $AppId android.permission.READ_SMS 2>$null | Out-Null
        & $script:Adb -s $script:Serial shell pm grant $AppId android.permission.RECEIVE_SMS 2>$null | Out-Null
        Write-Info "SMS permissions granted to $AppId."
    }

    # ---- Start the app -----------------------------------------------------

    if ($NoApp) {
        Write-Info 'Messages loaded; skipping app start (--no-app).'
        exit 0
    }

    if (-not $FlutterExe) { Stop-Script 'flutter not found. Add the Flutter SDK bin directory to PATH.' }

    $dartDefines = @("--dart-define=SMS_SYNC_MAX_MESSAGES=$MaxMessages")
    if ($ApiBase) {
        $dartDefines += "--dart-define=API_BASE_URL=$ApiBase"
    }

    Write-Info "Starting the app on $script:Serial (sync cap $MaxMessages) ..."
    Push-Location -LiteralPath $AppDir
    try {
        if ($Passthru.Count -gt 0) {
            & $FlutterExe run -d $script:Serial @dartDefines @Passthru
        }
        else {
            & $FlutterExe run -d $script:Serial @dartDefines
        }
        $FlutterExit = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    exit $FlutterExit
}
finally {
    Invoke-Cleanup
}
