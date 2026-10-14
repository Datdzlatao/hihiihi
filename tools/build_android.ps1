# Builds libcapyps5.so, packages the debug APK and installs it on the device.
#
#   powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 [-NoInstall] [-Device 282f344c]
#
# Paths default to this machine's setup; override with the environment variables below.
param(
    [switch]$NoInstall,
    [string]$Device = $(if ($env:CAPY_DEVICE) { $env:CAPY_DEVICE } else { "282f344c" })
)
$ErrorActionPreference = "Stop"

$Root   = Split-Path -Parent $PSScriptRoot
$Sdk    = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { "$env:LOCALAPPDATA\Android\Sdk" }
$Ndk    = "$Sdk\ndk\28.2.13676358"
$CMake  = "$Sdk\cmake\3.31.6\bin"
$Ninja  = if ($env:CAPY_NINJA_DIR) { $env:CAPY_NINJA_DIR } else { "$env:LOCALAPPDATA\Python\pythoncore-3.14-64\Scripts" }
$Build  = "$Root\build-android-arm64"
$JniDir = "$Root\android\app\src\main\jniLibs\arm64-v8a"
$Strip  = "$Ndk\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe"
$LibCxx = "$Ndk\toolchains\llvm\prebuilt\windows-x86_64\sysroot\usr\lib\aarch64-linux-android\libc++_shared.so"
$env:PATH = "$CMake;$Ninja;$env:PATH"
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = "C:\Program Files\Android\Android Studio2\jbr" }

if (-not (Test-Path "$Build\build.ninja")) {
    Write-Host "== Configuring native build"
    & cmake -S "$Root\core" -B $Build -G Ninja `
        "-DCMAKE_TOOLCHAIN_FILE=$Ndk\build\cmake\android.toolchain.cmake" `
        -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-31 -DCMAKE_BUILD_TYPE=Release `
        -DKYTY_BUILD_LAUNCHER=OFF
    if ($LASTEXITCODE) { throw "cmake configure failed" }
}

Write-Host "== Building libcapyps5.so"
& ninja -C $Build capyps5
if ($LASTEXITCODE) { throw "native build failed" }

# Debug info makes the library ~280 MB; keep the symbol table for readable tombstones.
New-Item -ItemType Directory -Force $JniDir | Out-Null
& $Strip --strip-debug -o "$JniDir\libcapyps5.so" "$Build\libcapyps5.so"
if ($LASTEXITCODE) { throw "strip failed" }
Copy-Item $LibCxx "$JniDir\libc++_shared.so" -Force

Write-Host "== Packaging APK"
Push-Location "$Root\android"
try {
    & .\gradlew.bat assembleDebug --console=plain -q
    if ($LASTEXITCODE) { throw "gradle build failed" }
} finally { Pop-Location }

$Apk = "$Root\android\app\build\outputs\apk\debug\app-debug.apk"
Write-Host ("APK: {0} ({1:N1} MB)" -f $Apk, ((Get-Item $Apk).Length / 1MB))

if (-not $NoInstall) {
    Write-Host "== Installing on $Device"
    & adb -s $Device install -r $Apk
    if ($LASTEXITCODE) { throw "adb install failed" }
}
