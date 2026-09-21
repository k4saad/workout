<#
    Finishes the Android toolchain so you can build an APK.

    Claude installed everything up to this line but deliberately stopped here:
    installing Android SDK packages requires ACCEPTING GOOGLE'S SDK LICENCE
    AGREEMENTS, which is a legal agreement and yours to accept, not Claude's.

    Run this once, in PowerShell:

        powershell -ExecutionPolicy Bypass -File tools\finish-android-setup.ps1

    It will print the licences and ask you to type 'y'. Takes ~5 minutes.
#>

$ErrorActionPreference = 'Stop'

$sdk    = 'C:\Users\Saad\Android\Sdk'
$jdk17  = (Get-ChildItem 'C:\Users\Saad\jdks' -Directory |
           Where-Object Name -like 'jdk-17*' | Select-Object -First 1).FullName
$flutter = 'C:\Users\Saad\flutter\bin\flutter.bat'
$sdkmgr = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"

Write-Host "`n=== Keller Twelve — finish Android setup ===`n" -ForegroundColor Cyan
Write-Host "Android SDK : $sdk"
Write-Host "JDK 17      : $jdk17"
Write-Host ""

if (-not (Test-Path $sdkmgr)) { throw "sdkmanager not found at $sdkmgr" }
if (-not $jdk17)              { throw "JDK 17 not found under C:\Users\Saad\jdks" }

$env:JAVA_HOME        = $jdk17
$env:ANDROID_HOME     = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:Path             = "$jdk17\bin;$env:Path"

Write-Host "STEP 1/4  Accept the Android SDK licences" -ForegroundColor Yellow
Write-Host "          You will be shown each licence. Type 'y' to accept.`n"
& $sdkmgr "--sdk_root=$sdk" --licenses

Write-Host "`nSTEP 2/4  Install SDK packages (~1.5 GB)" -ForegroundColor Yellow
& $sdkmgr "--sdk_root=$sdk" "platform-tools" "platforms;android-36" "build-tools;36.0.0"

Write-Host "`nSTEP 3/4  Point Flutter at the SDK and re-check" -ForegroundColor Yellow
& $flutter config --android-sdk $sdk --jdk-dir $jdk17
& $flutter doctor -v

Write-Host "`nSTEP 4/4  Build the signed release APK" -ForegroundColor Yellow
Set-Location (Join-Path $PSScriptRoot '..\app')
& $flutter build apk --release --split-per-abi

$apk = 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
if (Test-Path $apk) {
    Write-Host "`n--- verifying the signature is YOURS, not the debug key ---" -ForegroundColor Cyan
    $apksigner = Get-ChildItem "$sdk\build-tools" -Recurse -Filter 'apksigner.bat' |
                 Select-Object -First 1
    if ($apksigner) { & $apksigner.FullName verify --print-certs $apk }

    $sizeMB = [math]::Round((Get-Item $apk).Length / 1MB, 1)
    Write-Host "`nAPK built: $apk  ($sizeMB MB)" -ForegroundColor Green
    Write-Host @"

The certificate above must say  CN=Saad, OU=Keller Twelve  —
NOT  CN=Android Debug.  If it says Android Debug, stop and tell Claude.

To install on your phone:
  1. Phone: Settings -> About -> tap 'Build number' 7x -> Developer options
  2. Enable USB debugging (and 'Install via USB' on Xiaomi/Redmi/Realme)
  3. Plug in, then:
       $sdk\platform-tools\adb.exe devices
       $sdk\platform-tools\adb.exe install -r $apk

"@ -ForegroundColor Green
} else {
    Write-Host "`nBuild did not produce an APK. Check the output above." -ForegroundColor Red
}
