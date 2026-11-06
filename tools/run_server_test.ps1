# Headless check of the Walther PPK/S mod on a local dedicated server (test server "waltherppks_test").
#
# Copies the mod and the dev test-gun mod into ~/Zomboid/mods (real copies: a dedicated server without
# Steam does not scan ~/Zomboid/Workshop, and junctioned mods trigger NetChecksum "absPath:null" errors),
# starts the server, waits for the dev mod's "[WaltherPPKS-TEST] RESULT" line, stops the server,
# removes the copies and prints every mod-related line plus any ERROR/WARN mentioning the mods.
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools/run_server_test.ps1
param(
    [string]$Game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid",
    [int]$TimeoutSec = 240
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$zomboid = Join-Path $env:USERPROFILE "Zomboid"
$mods = Join-Path $zomboid "mods"
$ini = Join-Path $zomboid "Server\waltherppks_test.ini"
$log = Join-Path $env:TEMP "waltherppks_test_server.log"

$modsLine = "Mods=WaltherPPKS;WaltherPPKS_TestGun380"
if (Test-Path $ini) {
    $lines = @(Get-Content $ini | Where-Object { $_ -notmatch "^Mods=" })
    (@($modsLine) + $lines) | Set-Content -Encoding ascii $ini
} else {
    @(
        $modsLine, "WorkshopItems=", "Map=Muldraugh, KY",
        "Public=false", "Open=true", "PVP=false", "DefaultPort=16391", "UDPPort=16392"
    ) | Set-Content -Encoding ascii $ini
}

$copies = @(
    @{ src = Join-Path $root "workshop\WaltherPPKS\Contents\mods\WaltherPPKS"; dst = Join-Path $mods "WaltherPPKS" },
    @{ src = Join-Path $root "dev\WaltherPPKS_TestGun380"; dst = Join-Path $mods "WaltherPPKS_TestGun380" }
)
$created = @()   # only copies this run made are removed
$proc = $null
try {
    foreach ($c in $copies) {
        if (Test-Path $c.dst) { throw "$($c.dst) already exists; remove it first" }
        Copy-Item -Recurse $c.src $c.dst
        $created += $c.dst
    }

    $pw = -join ((48..57) + (97..102) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
    $javaArgs = @(
        "--enable-native-access=ALL-UNNAMED", "--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED",
        "-XX:+UseZGC", "-XX:-CreateCoredumpOnCrash", "-XX:-OmitStackTraceInFastThrow", "-Xmx3072m",
        "-Djava.library.path=./natives/;./natives/win64/;./", "-cp", "./;projectzomboid.jar",
        "zombie.network.GameServer", "-servername", "waltherppks_test", "-nosteam", "-adminpassword", $pw
    )
    $proc = Start-Process -FilePath (Join-Path $Game "jre64\bin\java.exe") -ArgumentList $javaArgs -WorkingDirectory $Game `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline -and -not $proc.HasExited) {
        if ((Test-Path $log) -and (Select-String -Path $log -Pattern "\[WaltherPPKS-TEST\] RESULT" -Quiet)) { break }
        Start-Sleep -Seconds 2
    }
} finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit(30000) | Out-Null
    }
    foreach ($d in $created) { if (Test-Path $d) { Remove-Item -Recurse -Force $d } }
}

$logs = @($log, "$log.err") | Where-Object { Test-Path $_ }
Select-String -Path $log -Pattern "loading WaltherPPKS|\[WaltherPPKS\] loot injected|\[WaltherPPKS-TEST\]" | ForEach-Object { $_.Line }
$bad = Select-String -Path $logs -Pattern "^(ERROR|WARN)" -Context 0,3 |
    Where-Object {
        $trace = $_.Context.PostContext | Where-Object { $_ -match "^\s" }   # stack-trace lines only
        ($_.Line + " " + ($trace -join " ")) -match "WaltherPPKS|PPKS|Bullets380|TestGun380"
    }
if ($bad) { "--- mod-related ERROR/WARN ---"; $bad | ForEach-Object { $_.Line } }
"full log: $log"
$passed = Select-String -Path $log -Pattern "\[WaltherPPKS-TEST\] RESULT PASS" -Quiet
if (-not $passed -or $bad) { "FAILED"; exit 1 }
"PASSED"
exit 0
