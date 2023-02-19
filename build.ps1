<#
.SYNOPSIS
NAnt2 build script.
.DESCRIPTION
Build script for NAnt2
.PARAMETER Tasks
One or more execution tasks(s), similar to NAnt or Cake targets as a string of tasks divided by comma
.PARAMETER BuildTarget
Build configuration (mono /.NET and framework version). Valid choices are net-4.5 and mono-4.5."
.PARAMETER BuildMode
MSBuild configuration. Valid choices are Debug and Release.
.PARAMETER Rebuild
Rebuilds the solution. Default is to do a simple build.
.PARAMETER WithCoverage
Calculate coverage when running tests
.PARAMETER StagingDir
Destination folder for staging build artifacts. If not provided it is assumed to be ''.\build''
.PARAMETER PublishDir
Destination folder for publishing build artifacts
.PARAMETER Version
Project version
.PARAMETER BuildNumber
CI build number
.RELEASENOTES
  1.0.0 - Initial version
#>

#Requires -Version 7.0
#Requires -PSEdition Core

#####################################
#Required script parameters
#####################################
param(
    [Parameter(Position=0, HelpMessage = "One or more execution tasks(s), similar to NAnt or Cake targets")]
	[string[]]$Tasks,

    [Parameter(HelpMessage = "Build configuration (mono /.NET and framework version). Valid choices are net-4.5 and mono-4.5.")]  
    #[ValidateSet('net-4.5', 'mono-4.5', IgnoreCase = $true, ErrorMessage="Value '{0}' is invalid. Try one of: '{1}'")]
    [string] $BuildTarget = 'net-4.5',

    [Parameter(HelpMessage = "MSBuild configuration. Valid choices are Debug and Release.")]  
    [ValidateSet('Debug', 'Release', IgnoreCase = $true, ErrorMessage="Value '{0}' is invalid. Try one of: '{1}'")]
    [string] $BuildMode = 'Debug',

    [Parameter(HelpMessage = 'Rebuilds the solution. Equivalent of clean + build')]
    [switch] $Rebuild,

    [Parameter(HelpMessage = 'Calculate coverage when running tests')]
    [switch] $WithCoverage,

    [Parameter(HelpMessage = 'Publish folder for the release artifacts. If not provided it is assumed to be ''.\publish''')]
    [string] $PublishDir,

    [Parameter(HelpMessage = 'Project version')]
    [string] $Version = '0.93',

    [Parameter(HelpMessage = 'CI build number')]
    [string] $BuildNumber = '0'
)


Set-StrictMode -Version latest

function Set-PSModules {
    param(
        [Parameter(HelpMessage = 'Installs or loads the given powershell module(s)')]
        [string[]]$Modules
    )

    $policy = (Get-PSRepository PSGallery).InstallationPolicy
    try{
        foreach ($module in $Modules) {
            if (Get-Module -ListAvailable -Name $module) {
                Write-Host "$module module exists"
            } 
            else {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                Install-Module $module -Scope CurrentUser -AcceptLicense
            }

            Import-Module $module
        }
    }
    finally{
        Set-PSRepository PSGallery -InstallationPolicy $policy
    }
}

function Get-MsBuild {
    <#
    .SYNOPSIS 
    Gets the path to latest 'MSBuild'
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
    $result.CompilerLanguage = 5 # .NET 4.5 compiler, see https://github.com/philippgille/docs-1/blob/master/docs/csharp/language-reference/compiler-options/langversion-compiler-option.md

    if($result.Platform -in ("net", "mono") -and $result.Version -lt [System.Version]'5.0') {
        #Still on .NET framework
        $result.Compiler = "csc" #Available since Mono v5, see https://halfblood.pro/the-rough-history-of-the-so-many-c-compilers-f3a85500707c        
        $result.DotNetRunner = $IsWindows ? "" : "mono"
        $result.ResgenExe = $IsWindows ? "resgen.exe" : "resgen"
    }

    if($IsDebug)
    {
        $result.CompilerDebug = "/debug"
    }

    return $result
}

#####################################################
#      initialization: Invoke-Build module
#####################################################
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
	$ErrorActionPreference = 'Stop'
    $policy = (Get-PSRepository PSGallery).InstallationPolicy
	try {
		Import-Module InvokeBuild
	}
	catch {
        Set-PSRepository PSGallery -InstallationPolicy Trusted
		Install-Module InvokeBuild -Scope CurrentUser -Force -Repository PSGallery -SkipPublisherCheck -Verbose
		Import-Module InvokeBuild
	}
    finally {
        Set-PSRepository PSGallery -InstallationPolicy $policy
    }
    
    try {
        Invoke-Build -Task $Tasks -File $MyInvocation.MyCommand.Path @PSBoundParameters
    } 
    catch { 
        $PSItem | Format-List * -Force | Out-String
        $LASTEXITCODE = 1
    }
    if(0 -ne $LASTEXITCODE)
    {
        Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Red
    }
    exit $LASTEXITCODE
}

#####################################################
#         initialization: global variables
#####################################################
if(-not $PublishDir) {
    $PublishDir = Join-Path $BuildRoot "publish"
}
if(-not (Test-Path -LiteralPath $PublishDir))
{
    New-Item $PublishDir -ItemType Directory -Force
}

$SRC_DIR = Join-Path $BuildRoot "src"
$TESTS_DIR = Join-Path $BuildRoot "tests"
$BOOTSTRAP_DIR = Join-Path $BuildRoot "bootstrap"
$BUILD_DIR = Join-Path $BuildRoot "build"
$PUBLISH_DIR = $PublishDir

$TOOLS_DIR = Join-Path $BuildRoot "tools"
$REPORTS_DIR = Join-Path $BuildRoot "reports"

$MSBUILD = Get-MsBuild -ToolsDir $TOOLS_DIR
$BUILD_CONFIGURATION = Get-BuildConfiguration -FrameworkTarget $BuildTarget -IsDebug:$($BuildMode -eq 'Debug')

#MSBuild paralelism
$parallelism = 3
#MSBuild verbosity: q[uiet], m[inimal], n[ormal] (default), d[etailed], and diag[nostic]
$verbosity = 'm'

#####################################################
#      initialization: before build
#####################################################
Enter-Build {
    Write-Build Blue "
    Src directory: $SRC_DIR,
    Tests directory: $TESTS_DIR,
    Boostrap directory: $BOOTSTRAP_DIR,
    Build directory: $BUILD_DIR,
    Publish directory: $PUBLISH_DIR,
    Tools directory: $TOOLS_DIR,
    Reports directory: $REPORTS_DIR,
    msbuild.exe path: $MSBUILD,
    Build configuration - platform: $($BUILD_CONFIGURATION.Platform),
    Build configuration - version: $($BUILD_CONFIGURATION.Version),
    Build configuration - compilation flags: $($BUILD_CONFIGURATION.CompilationFlags),
    Build configuration - compiler: $($BUILD_CONFIGURATION.Compiler),
    Build configuration - compiler language: $($BUILD_CONFIGURATION.CompilerLanguage),
    Build configuration - .net runner: $($BUILD_CONFIGURATION.DotNetRunner),
    Build configuration - resgen executable: $($BUILD_CONFIGURATION.ResgenExe),
    Build configuration - compiler debug flag: $($BUILD_CONFIGURATION.CompilerDebug)"
}

#####################################
#          Tasks
#####################################
task Init {
    <#
    .SYNOPSIS
    Initialization of any folder structure of files required for a succesful build
    #>
    Write-Output '[Init] Preparing to run build script'

    # Make sure bootstrap folder exists
    if ((Test-Path $BuildRoot) -and !(Test-Path $BOOTSTRAP_DIR)) {
        Write-Output "[Init] Creating bootstrap directory..."
        New-Item -Path $BOOTSTRAP_DIR -Type Directory -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $BuildRoot 'lib') -Destination $BOOTSTRAP_DIR -Recurse -Force
    # Mono loads log4net before privatebinpath is set-up, so we need this in the same directory as NAnt.exe
    Copy-Item -Path (Join-Path $BuildRoot 'lib' 'common' 'neutral' '*') -Include 'log4net.dll' -Destination $BOOTSTRAP_DIR -Force
    Copy-Item -Path (Join-Path $SRC_DIR 'NAnt.Console' '*') -Include 'App.config' -Destination (Join-Path $BOOTSTRAP_DIR 'NAnt.exe.config') -Force

    # Make sure publish folder exists
    if ((Test-Path $BuildRoot) -and $BuildMode -eq 'Release' -and !(Test-Path $PUBLISH_DIR)) {
        Write-Output "[Init] Creating publish directory..."
        New-Item -Path $PUBLISH_DIR -Type Directory -Force | Out-Null
    }

    # Make sure reports folder exists
    if ((Test-Path $BuildRoot) -and !(Test-Path $REPORTS_DIR)) {
        Write-Output "[Init] Creating reports directory..."
        New-Item -Path $REPORTS_DIR -Type Directory -Force | Out-Null
    }
}

task Clean {
    <#
    .SYNOPSIS 
    Executes any cleanup required before building the project.
    #>
    if (Test-Path $BOOTSTRAP_DIR ) {
        Write-Output "[Clean] Cleaning bootstrap directory..."
        Get-ChildItem -Path $BOOTSTRAP_DIR | Remove-Item -Recurse -Force -ErrorAction Ignore
    }

    if (Test-Path $BUILD_DIR ) {
        Write-Output "[Clean] Cleaning build directory..."
        Get-ChildItem -Path $BUILD_DIR | Remove-Item -Recurse -Force -ErrorAction Ignore
    }

    if (Test-Path $PUBLISH_DIR ) {
        Write-Output "[Clean] Cleaning publish directory..."
        Get-ChildItem -Path $PUBLISH_DIR | Remove-Item -Recurse -Force -ErrorAction Ignore
    }

    Write-Output '[Clean] Cleaning reports folder except NDepend one'
    if (Test-Path $REPORTS_DIR ) {
        Write-Output -Message "[Clean] Cleaning reports directory..."
        Get-ChildItem -Path $REPORTS_DIR -Exclude NDependOut | Remove-Item -Recurse -Force -ErrorAction Ignore
    }
}

task Deep-Clean Clean, {
    <#
    .SYNOPSIS 
    Executes default cleanup (boostrap, build, publish and reports directories) and also cleans /bin and /obj folders
    #>

    Write-Output "[Deep-Clean] Cleaning /bin and /obj folders from $SRC_DIR, tests and $TOOLS_DIR"
    Get-ChildItem $SRC_DIR -Include bin,obj -Recurse | Remove-Item -Recurse -Force -ErrorAction Ignore
    Get-ChildItem (Join-Path $BuildRoot "tests") -Include bin,obj -Recurse | Remove-Item -Recurse -Force -ErrorAction Ignore
    Get-ChildItem $TOOLS_DIR -Include bin,obj -Recurse | Remove-Item -Recurse -Force -ErrorAction Ignore
}

task Bootstrap Clean, Init, {
    <#
    .SYNOPSIS 
    Builds NAnt.exe, NAnt.Core, NAnt.DotNet, NAnt.Compression and, if on Windows, NAnt.Win32 and places them in bootstrap dir
    #>

    Write-Output "[Bootstrap] Building NAnt.exe"
    # Bootstrap NAnt.exe
    & $($BUILD_CONFIGURATION.Compiler) `
            $($BUILD_CONFIGURATION.CompilerDebug) `
            /target:exe `
            /platform:anycpu `
            /langversion:$($BUILD_CONFIGURATION.CompilerLanguage) `
            /define:$($BUILD_CONFIGURATION.CompilationFlags) `
            /out:$(Join-Path $BOOTSTRAP_DIR 'NAnt.exe') `
            /r:$(Join-Path $BOOTSTRAP_DIR 'log4net.dll') `
            /r:System.Configuration.dll `
            /recurse:$(Join-Path $SRC_DIR 'NAnt.Console' '*.cs') $(Join-Path $SRC_DIR SolutionInfo.cs)
    
    #$(MCS) $(DEBUG) -target:exe -define:$(DEFINE) -out:bootstrap${DIRSEP}NAnt.exe -r:bootstrap${DIRSEP}log4net.dll \
	#	-r:System.Configuration.dll -recurse:src${DIRSEP}NAnt.Console${DIRSEP}*.cs src${DIRSEP}SolutionInfo.cs
    
    Write-Output "[Bootstrap] Building NAnt.Core"
    # Bootstrap NAnt.Core.dll
    & $($BUILD_CONFIGURATION.ResgenExe) `
            $(Join-Path $SRC_DIR 'NAnt.Core' 'Resources' 'Strings.resx') `
            $(Join-Path $BOOTSTRAP_DIR 'NAnt.Core.Resources.Strings.resources')
    assert($LastExitCode -eq 0) "Resource generation for NAnt.Core failed"

    & $($BUILD_CONFIGURATION.Compiler) `
        $($BUILD_CONFIGURATION.CompilerDebug) `
        /target:library `
        /platform:anycpu `
        /langversion:$($BUILD_CONFIGURATION.CompilerLanguage) `
        /warn:0 `
        /define:$($BUILD_CONFIGURATION.CompilationFlags) `
        /out:$(Join-Path $BOOTSTRAP_DIR 'NAnt.Core.dll') `
        /resource:$(Join-Path $BOOTSTRAP_DIR 'NAnt.Core.Resources.Strings.resources') `
        /r:$(Join-Path $BOOTSTRAP_DIR 'log4net.dll') `
        /r:System.Web.dll `
        /r:System.Configuration.dll `
        /recurse:$(Join-Path $SRC_DIR 'NAnt.Core' '*.cs') $(Join-Path $SRC_DIR SolutionInfo.cs)
    assert($LastExitCode -eq 0) "Compilation of NAnt.Core failed"

    #$(RESGEN)  src/NAnt.Core/Resources/Strings.resx bootstrap/NAnt.Core.Resources.Strings.resources
	#$(MCS) $(DEBUG) -target:library -warn:0 -define:$(DEFINE) -out:bootstrap/NAnt.Core.dll -debug \
	#	-resource:bootstrap/NAnt.Core.Resources.Strings.resources -r:lib${DIRSEP}common${DIRSEP}neutral${DIRSEP}log4net.dll \
	#	-r:System.Web.dll -r:System.Configuration.dll -recurse:src${DIRSEP}NAnt.Core${DIRSEP}*.cs src${DIRSEP}SolutionInfo.cs

    Write-Output "[Bootstrap] Building NAnt.DotNet"
    # Bootstrap NAnt.DotNetTasks.dll
    & $($BUILD_CONFIGURATION.ResgenExe) `
            $(Join-Path $SRC_DIR 'NAnt.DotNet' 'Resources' 'Strings.resx') `
            $(Join-Path $BOOTSTRAP_DIR 'NAnt.DotNet.Resources.Strings.resources')
    assert($LastExitCode -eq 0) "Resource generation for NAnt.DotNet failed"
    
    & $($BUILD_CONFIGURATION.Compiler) `
            $($BUILD_CONFIGURATION.CompilerDebug) `
            /target:library `
            /platform:anycpu `
            /langversion:$($BUILD_CONFIGURATION.CompilerLanguage) `
            /warn:0 `
            /define:$($BUILD_CONFIGURATION.CompilationFlags) `
            /out:$(Join-Path $BOOTSTRAP_DIR 'NAnt.DotNetTasks.dll') `
            /resource:$(Join-Path $BOOTSTRAP_DIR 'NAnt.DotNet.Resources.Strings.resources') `
            /r:$(Join-Path $BOOTSTRAP_DIR 'NAnt.Core.dll') `
            /r:$(Join-Path $BOOTSTRAP_DIR 'lib' 'common' 'neutral' 'NDoc.Core.dll') `
            /recurse:$(Join-Path $SRC_DIR 'NAnt.DotNet' '*.cs') `
            $(Join-Path $SRC_DIR SolutionInfo.cs)
    assert($LastExitCode -eq 0) "Compilation of NAnt.DotNet failed"

    #$(RESGEN)  src/NAnt.DotNet/Resources/Strings.resx bootstrap/NAnt.DotNet.Resources.Strings.resources
	#$(MCS) $(DEBUG) -target:library -warn:0 -define:$(DEFINE) -out:bootstrap/NAnt.DotNetTasks.dll \
	#	-r:./bootstrap/NAnt.Core.dll -r:bootstrap/lib/common/neutral/NDoc.Core.dll \
	#	-recurse:src${DIRSEP}NAnt.DotNet${DIRSEP}*.cs -resource:bootstrap/NAnt.DotNet.Resources.Strings.resources \
	#	src${DIRSEP}SolutionInfo.cs

    Write-Output "[Bootstrap] Building NAnt.Compression"
    # Bootstrap NAnt.CompressionTasks.dll
    & $($BUILD_CONFIGURATION.Compiler) `
            $($BUILD_CONFIGURATION.CompilerDebug) `
            /target:library `
            /platform:anycpu `
            /langversion:$($BUILD_CONFIGURATION.CompilerLanguage) `
            /warn:0 `
            /define:$($BUILD_CONFIGURATION.CompilationFlags) `
            /out:$(Join-Path $BOOTSTRAP_DIR 'NAnt.CompressionTasks.dll') `
            /r:$(Join-Path $BOOTSTRAP_DIR 'NAnt.Core.dll') `
            /r:$(Join-Path $BOOTSTRAP_DIR 'lib' 'common' 'neutral' 'ICSharpCode.SharpZipLib.dll') `
            /recurse:$(Join-Path $SRC_DIR 'NAnt.Compression' '*.cs') `
            $(Join-Path $SRC_DIR SolutionInfo.cs)
    assert($LastExitCode -eq 0) "Compilation of NAnt.Compression failed"

    #$(MCS) $(DEBUG) -target:library -warn:0 -define:$(DEFINE) -out:bootstrap/NAnt.CompressionTasks.dll \
	#	-r:./bootstrap/NAnt.Core.dll -r:bootstrap/lib/common/neutral/ICSharpCode.SharpZipLib.dll \
	#	-recurse:src${DIRSEP}NAnt.Compression${DIRSEP}*.cs src${DIRSEP}SolutionInfo.cs

    # Bootstrap NAnt.Win32Tasks.dll if on Windows
    if($IsWindows) {
        Write-Output "[Bootstrap] On Windows. Building NAnt.Win32"
        & $($BUILD_CONFIGURATION.Compiler) `
                $($BUILD_CONFIGURATION.CompilerDebug) `
                /target:library `
                /platform:anycpu `
                /langversion:$($BUILD_CONFIGURATION.CompilerLanguage) `
                /warn:0 `
                /define:$($BUILD_CONFIGURATION.CompilationFlags) `
                /out:$(Join-Path $BOOTSTRAP_DIR 'NAnt.Win32Tasks.dll') `
                /r:$(Join-Path $BOOTSTRAP_DIR 'NAnt.Core.dll') `
                /r:$(Join-Path $BOOTSTRAP_DIR 'NAnt.DotNetTasks.dll') `
                /r:System.ServiceProcess.dll `
                /recurse:$(Join-Path $SRC_DIR 'NAnt.Win32' '*.cs') `
                $(Join-Path $SRC_DIR SolutionInfo.cs)
        assert($LastExitCode -eq 0) "Compilation of NAnt.Win32 failed"
    }
    #$(MCS) $(DEBUG) -target:library -warn:0 -define:$(DEFINE) -out:bootstrap/NAnt.Win32Tasks.dll \
	#	-r:./bootstrap/NAnt.Core.dll -r:./bootstrap/NAnt.DotNetTasks.dll -r:System.ServiceProcess.dll \
	#	-recurse:src${DIRSEP}NAnt.Win32${DIRSEP}*.cs src${DIRSEP}SolutionInfo.cs
}

task Build-NAnt Bootstrap, {
    <#
    .SYNOPSIS 
    Builds the rest of the NAnt projects using the boostraped NAnt.exe
    #>

    Write-Output "[Build-NAnt] Building all NAnt projects"
    & $($BUILD_CONFIGURATION.DotNetRunner) $(Join-Path $BOOTSTRAP_DIR 'NAnt.exe') `
            -j $(($BuildMode -eq 'Debug') ? '-debug+' : '') `
            -t:$BuildTarget `
            -D:project.version=$Version `
            -D:build.number=$BuildNumber `
            -verbose `
            -f:NAnt.build `
            build
    #	$(NANT) $(TARGET_FRAMEWORK) -f:NAnt.build build
}

task Run-Test Bootstrap, {
    <#
    .SYNOPSIS 
    Builds the rest of the NAnt projects using the boostraped NAnt.exe and runs all available tests
    #>

    Write-Output "[Run-Test] Building and runing all tests for all NAnt projects"
    & $($BUILD_CONFIGURATION.DotNetRunner) $(Join-Path $BOOTSTRAP_DIR 'NAnt.exe') `
            -j $(($BuildMode -eq 'Debug') ? '-debug+' : '') `
            -t:$BuildTarget `
            -D:project.version=$Version `
            -D:build.number=$BuildNumber `
            -verbose `
            -f:NAnt.build `
            test
    #   $(NANT) $(TARGET_FRAMEWORK) -f:NAnt.build test
}

task Run-CodeQuality Bootstrap, {
    <#
    .SYNOPSIS 
    Builds everything, runs the tests and calculates code coverage
    #>

    Write-Output "[Run-Test] Code quality analysis of NAnt projects"
    & $($BUILD_CONFIGURATION.DotNetRunner) $(Join-Path $BOOTSTRAP_DIR 'NAnt.exe') `
            -j $(($BuildMode -eq 'Debug') ? '-debug+' : '') `
            -t:$BuildTarget `
            -D:project.version=$Version `
            -D:build.number=$BuildNumber `
            -verbose `
            -f:NAnt.build `
            run-codequality
    #   $(NANT) $(TARGET_FRAMEWORK) -f:NAnt.build test
}

task Stage {

    #$(NANT) $(TARGET_FRAMEWORK) -f:NAnt.build install -D:prefix="$(prefix)" -D:destdir="$(DESTDIR)" -D:doc.prefix="$(docdir)"
}


task All Bootstrap, Build-NAnt

#region Default Task
task . Build