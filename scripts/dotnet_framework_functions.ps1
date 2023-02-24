function Invoke-VsDevCmd {
    <#
    .SYNOPSIS 
    Sets environment variables from VsDevCmd without creating a nested prompt (so that resgen.exe can be located)
    .PARAMETER ToolsDir
    Path to the tools folder (where vswhere.exe is located for Windows builds)
    .LINK
    https://github.com/Microsoft/vswhere/wiki/Start-Developer-Command-Prompt#using-powershell
    #>
    param(
        [Parameter(HelpMessage = 'Path to tools folder')]
        [string] $ToolsDir
    )

    Write-Build DarkBlue "Setup of VsDevCmd starting..."

    if($IsWindows)
    {
        #set environment variables from VsDevCmd without creating a nested prompt 
        $installationPath = & $(Join-Path $ToolsDir 'vswhere.exe') -prerelease -latest -property installationPath
        Write-Output "Visual Studio install folder: $installationPath"
        if ($installationPath -and (Test-Path "$installationPath\Common7\Tools\vsdevcmd.bat")) {
        & "${env:COMSPEC}" /s /c "`"$installationPath\Common7\Tools\vsdevcmd.bat`" -no_logo && set" | ForEach-Object {
            $name, $value = $_ -split '=', 2
            Set-Content env:\"$name" $value
            }
        }

        $cscVersion = & csc /version
        Write-Output "csc version: $cscVersion"
    }
    else {
        Write-Output "Not on Windows. Nothing to do"
    }

    Write-Build DarkBlue "Setup of VsDevCmd completed"
}
function Get-MsBuild {
    <#
    .SYNOPSIS 
    Gets the path to latest 'MSBuild'
    .PARAMETER ToolsDir
    Path to the tools folder (where vswhere.exe is located for Windows builds)
    #>
    param(
        [Parameter(HelpMessage = 'Path to tools folder')]
        [string] $ToolsDir
    )

    # for TFMs less than net462, use MSBuild (provided by .NET Framework or mono)
    # see https://halfblood.pro/locate-msbuild-via-powershell-on-different-operating-systems-140757bb8e18
    $msBuild_exe = "msbuild"
    if($IsWindows) {
        $vswhere_exe = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if(-not (Test-Path -LiteralPath $vswhere_exe)) {
            $vswhere_exe = Join-Path $toolsDir "wswhere.exe"
        }
        $msBuild_exe = & $VSWHERE_EXE -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | Select-Object -first 1

        #TODO: Detect Mono on Windows
    }

    return $msBuild_exe
}

function Get-BuildConfiguration {
    <#
    .SYNOPSIS
    Returns build parameters (compilation flags, resgen command, .NET platform, .NET version, compiler name, compilation flags ) 
    based on the build target framework and operating system
    .PARAMETER FrameworkTarget
    Build configuration (combination of build platform and version {platform}-{version})
    .PARAMETER IsDebug
    MSBuild configuration. Valid choices are Debug and Release
    .EXAMPLE
    Get-BuildConfiguration -FrameworkTarget 'mono-4.5' -IsDebug
    #>
    param(
        [Parameter(HelpMessage = "Build configuration (combination of build platform and version {platform}-{version})")]  
        [string] $FrameworkTarget,

        [Parameter(HelpMessage = "MSBuild configuration. Valid choices are Debug and Release.")]
        [switch] $IsDebug = $true
    )

    $result = @{}

    assert ($FrameworkTarget -ne '') "No valid build target to determine compilation flags"
    if ($FrameworkTarget -match '(?<platform>((?:mono)|(?:net)))-(?<version>(\d+(\.\d+){1,3}))')
    {
        $result = @{
            Platform = $matches.platform
            Version = [System.Version]$matches.version
        }        
    }
    else{
        throw "Buid target unrecognized. It could not be parsed to determine required compilation flags"
    }

    $compilationFlags = ($result.Platform -eq "mono") ? @("MONO") : @()
    $compilationFlags += ($IsWindows) ? "WINDOWS" : (($IsLinux) ? "LINUX" : "MACOS")

    if($result.Platform -in ("net", "mono") -and $result.Version -lt [System.Version]'5.0')
    {
        $compilationFlags += "NETFRAMEWORK"

        if($result.Version -eq "4.0")
        {
            $compilationFlags += ("NET40", "NET40_OR_GREATER",
                                "NET40_OR_LESSER", "NET45_OR_LESSER", "NET451_OR_LESSER", "NET452_OR_LESSER", "NET46_OR_LESSER", "NET461_OR_LESSER", "NET462_OR_LESSER", "NET47_OR_LESSER", "NET471_OR_LESSER", "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.5")
        {
            $compilationFlags += ("NET45",
                                "NET40_OR_GREATER", "NET45_OR_GREATER",
                                "NET45_OR_LESSER", "NET451_OR_LESSER", "NET452_OR_LESSER", "NET46_OR_LESSER", "NET461_OR_LESSER", "NET462_OR_LESSER", "NET47_OR_LESSER", "NET471_OR_LESSER", "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.5.1")
        {
            $compilationFlags += ("NET451", 
                                "NET40_OR_GREATER", "NET45_OR_GREATER", "NET451_OR_GREATER", 
                                "NET451_OR_LESSER", "NET452_OR_LESSER", "NET46_OR_LESSER", "NET461_OR_LESSER", "NET462_OR_LESSER", "NET47_OR_LESSER", "NET471_OR_LESSER", "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.5.2")
        {
            $compilationFlags += ("NET452", 
                                "NET40_OR_GREATER", "NET45_OR_GREATER", "NET451_OR_GREATER", "NET452_OR_GREATER",
                                "NET452_OR_LESSER", "NET46_OR_LESSER", "NET461_OR_LESSER", "NET462_OR_LESSER", "NET47_OR_LESSER", "NET471_OR_LESSER", "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.6")
        {
            $compilationFlags += ("NET46", 
                                "NET40_OR_GREATER", "NET45_OR_GREATER", "NET451_OR_GREATER", "NET452_OR_GREATER", "NET46_OR_GREATER",
                                "NET46_OR_LESSER", "NET461_OR_LESSER", "NET462_OR_LESSER", "NET47_OR_LESSER", "NET471_OR_LESSER", "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.6.1")
        {
            $compilationFlags += ("NET461",
                                "NET40_OR_GREATER", "NET45_OR_GREATER", "NET451_OR_GREATER", "NET452_OR_GREATER", "NET46_OR_GREATER", "NET461_OR_GREATER",
                                "NET461_OR_LESSER", "NET462_OR_LESSER", "NET47_OR_LESSER", "NET471_OR_LESSER", "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.6.2")
        {
            $compilationFlags += ("NET462",
                                "NET40_OR_GREATER", "NET45_OR_GREATER", "NET451_OR_GREATER", "NET452_OR_GREATER", "NET46_OR_GREATER", "NET461_OR_GREATER", "NET462_OR_GREATER",
                                "NET462_OR_LESSER", "NET47_OR_LESSER", "NET471_OR_LESSER", "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.7")
        {
            $compilationFlags += ("NET47",
                                "NET40_OR_GREATER", "NET45_OR_GREATER", "NET451_OR_GREATER", "NET452_OR_GREATER", "NET46_OR_GREATER", "NET461_OR_GREATER", "NET462_OR_GREATER", "NET47_OR_GREATER",
                                "NET47_OR_LESSER", "NET471_OR_LESSER", "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.7.1")
        {
            $compilationFlags += ("NET471",
                                "NET40_OR_GREATER", "NET45_OR_GREATER", "NET451_OR_GREATER", "NET452_OR_GREATER", "NET46_OR_GREATER", "NET461_OR_GREATER", "NET462_OR_GREATER", "NET47_OR_GREATER","NET471_OR_GREATER",
                                "NET471_OR_LESSER", "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.7.2")
        {
            $compilationFlags += ("NET472",
                                "NET40_OR_GREATER", "NET45_OR_GREATER", "NET451_OR_GREATER", "NET452_OR_GREATER", "NET46_OR_GREATER", "NET461_OR_GREATER", "NET462_OR_GREATER", "NET47_OR_GREATER", "NET472_OR_GREATER",
                                "NET472_OR_LESSER", "NET48_OR_LESSER")
        }
        if($result.Version -eq "4.8")
        {
            $compilationFlags += ("NET48",
                                "NET40_OR_GREATER", "NET45_OR_GREATER", "NET451_OR_GREATER", "NET452_OR_GREATER", "NET46_OR_GREATER", "NET461_OR_GREATER", "NET462_OR_GREATER", "NET47_OR_GREATER", "NET472_OR_GREATER", "NET48_OR_GREATER",
                                "NET48_OR_LESSER")
        }
    }
    $result.CompilationFlags = $($compilationFlags -join ';')
    $result.CompilerLanguage = 7.3 # max supported by .NET 4.5 compiler, see https://github.com/philippgille/docs-1/blob/master/docs/csharp/language-reference/compiler-options/langversion-compiler-option.md

    if($result.Platform -in ("net", "mono") -and $result.Version -lt [System.Version]'5.0') {
        #Still on .NET framework
        $result.Compiler = "csc" #Available since Mono v5, see https://halfblood.pro/the-rough-history-of-the-so-many-c-compilers-f3a85500707c
        $result.ResgenExe = $IsWindows ? "resgen.exe" : "resgen"
    }

    if($IsDebug)
    {
        $result.CompilerDebug = "/debug"
    }

    return $result
}