<#
    Main build script for NAnt
#>

#Steps:
#   1. detect OS version; use $IsWindows / !$IsWindows
#   2. detect installed versions of .NET framework, Mono, .NET Core
#   3. create 'bootstrap' and 'bootstrap\lib' folder
#   4. copy all from 'lib' to bootstrap\lib
#   5. copy 'lib\common\neutral\log4net' to 'bootstrap'
#   5. copy 'src\NAnt.Console\App.config' to 'bootstrap\NAnt.exe.config'
#   6. run 'csc  -target:exe -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.exe -r:bootstrap\log4net.dll  -r:System.Configuration.dll  -recurse:src\NAnt.Console\*.cs src\CommonAssemblyInfo.cs'
#   7. run 'resgen  src\NAnt.Core\Resources\Strings.resx bootstrap\NAnt.Core.Resources.Strings.resources'
#   8. csc  -target:library -warn:0 -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.Core.dll -r:bootstrap\log4net.dll  -r:System.Web.dll -r:System.Configuration.dll -resource:bootstrap\NAnt.Core.Resources.Strings.resources  -recurse:src\NAnt.Core\*.cs src\CommonAssemblyInfo.cs
#   9. resgen.exe  src\NAnt.DotNet\Resources\Strings.resx bootstrap\NAnt.DotNet.Resources.Strings.resources
#   10. 'csc  -target:library -warn:0 -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.DotNetTasks.dll  -r:bootstrap\NAnt.Core.dll -r:bootstrap/lib/common/neutral/NDoc.Core.dll  -resource:bootstrap\NAnt.DotNet.Resources.Strings.resources -recurse:src\NAnt.DotNet\*.cs  src\CommonAssemblyInfo.cs'
#   11. 'csc  -target:library -warn:0 -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.CompressionTasks.dll  -r:bootstrap\NAnt.Core.dll -r:bootstrap\lib\common\neutral\ICSharpCode.SharpZipLib.dll -recurse:src\NAnt.Compression\*.cs src\CommonAssemblyInfo.cs'
#   12. 'csc  -target:library -warn:0 -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.Win32Tasks.dll  -r:bootstrap\NAnt.Core.dll -r:bootstrap\NAnt.DotNetTasks.dll -r:System.ServiceProcess.dll  -recurse:src\NAnt.Win32\*.cs  src\CommonAssemblyInfo.cs'
#   13. 'bootstrap\NAnt.exe -j  -t:net-4.0 -f:NAnt.build install -D:prefix="d:\Simona Avornicesei\Projects\nant2\build"  -D:destdir="" -D:doc.prefix=""

param(
    [string]$BuildNumber = "0",
    [string]$Version = "0.95"
)

$ErrorActionPreference = 'STOP' #Whenever Write-Error is used, it will produce a terminating error

function Invoke-Build
{
    param(
        [string]$TargetFramework = "mono-4.5"
    )

    switch -Exact ($TargetFramework) 
    {
        "mono-4.0" 
        {  
            make clean build-nant TARGET=mono-4.0 MCS="mcs -sdk:4" build=$BuildNumber version=$Version
            break
        }
        "net-4.0" 
        {  
            make clean build-nant TARGET=net-4.0 MCS="mcs -sdk:4" build=$BuildNumber version=$Version
            break
        }
        "net-4.5" 
        {  
            make clean build-nant TARGET=net-4.5 MCS="mcs -sdk:4.5" build=$BuildNumber version=$Version
            break
        }
        Default 
        {
            make clean build-nant TARGET=mono-4.5 MCS="mcs -sdk:4.5" build=$BuildNumber version=$Version
            break
        }
    }

    if ($LASTEXITCODE -ne 0)
    {
        Write-Error "Error when building nant"
    }
}

function Invoke-Tests
{
    param(
        [string]$TargetFramework = "mono-4.5"
    )

    switch -Exact ($TargetFramework) 
    {
        "mono-4.0" 
        {  
            make clean run-test TARGET=mono-4.0 MCS="mcs -sdk:4" build=$BuildNumber version=$Version
            break
        }
        "net-4.0" 
        {  
            make clean run-test TARGET=net-4.0 MCS="mcs -sdk:4" build=$BuildNumber version=$Version
            break
        }
        "net-4.5" 
        {  
            make clean run-test TARGET=net-4.5 MCS="mcs -sdk:4.5" build=$BuildNumber version=$Version
            break
        }
        Default 
        {
            make clean run-test TARGET=mono-4.5 MCS="mcs -sdk:4.5" build=$BuildNumber version=$Version
            break
        }
    }

    if ($LASTEXITCODE -ne 0)
    {
        Write-Error "Error when running nant tests"
    }
}

Write-Host "[Windows] Build and run tests on mono for version $Version and build number $BuildNumber"

$env:MONO323_HOME = "${env:ProgramFiles(x86)}\Mono-3.2.3"
$env:MONO442_HOME = "${env:ProgramFiles(x86)}\Mono"
$env:MONO64_HOME = "$env:PROGRAMFILES\Mono"

Write-Host "[choco] Installing make"
choco install -yf make
refreshenv
Write-Host "[choco] Uninstall any existing mono packages installed"
choco uninstall mono --all-versions -y -f

Write-Host "--------------------------------"
Write-Host "mono-3.2.2: Building and testing"
Write-Host "--------------------------------"
Write-Host "-- [choco] Installing mono 3.2.3"
choco install mono --version=3.2.3 -yf
Write-Host "-- [env] Add mono to PATH"
$env:PATH += ";$env:MONO323_HOME\bin"
mono --version
Write-Host "-- [make] Build and run tests"
Invoke-Build -TargetFramework net-4.0
Invoke-Tests -TargetFramework net-4.0
Write-Host "-- [choco] Removing mono 3.2.3"
choco uninstall mono --version=3.2.3 -yfn

Write-Host "--------------------------------"
Write-Host "mono-4.4.2: Building and testing"
Write-Host "--------------------------------"
Write-Host "-- [choco] Installing mono 4.4.2"
choco install mono --version=4.4.2 -yf
Write-Host "-- [env] Add mono to PATH"
$env:PATH += ";$env:MONO442_HOME\bin"
mono --version
Write-Host "-- [make] Build and run tests"
Invoke-Build
Invoke-Tests
Write-Host "-- [choco] Removing mono 4.4.2"
choco uninstall mono --version=4.4.2 -yfn

Write-Host "------------------------------------"
Write-Host "mono-5.20.1.34: Building and testing"
Write-Host "------------------------------------"
Write-Host "-- [choco] Installing mono 5.20.1.34"
choco install mono --version=5.20.1.34 -yf
Write-Host "-- [env] Add mono to PATH"
$env:PATH += ";$env:MONO64_HOME\bin"
mono --version
Write-Host "-- [make] Build and run tests"
Invoke-Build
Invoke-Tests

Write-Host "-------------------------------------"
Write-Host "mono-6.12.0.107: Building and testing"
Write-Host "-------------------------------------"
Write-Host "-- [choco] Installing mono 6.12.0.107"
choco upgrade mono --version=6.12.0.107 -yf
mono --version
Write-Host "-- [make] Build and run tests"
Invoke-Build
Invoke-Tests