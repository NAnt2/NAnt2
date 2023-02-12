<#
.SYNOPSIS
NAnt2 build script.

.DESCRIPTION
Build script for NAnt2
.PARAMETER Tasks
One or more execution tasks(s), similar to NAnt or Cake targets as a string of tasks divided by comma
.PARAMETER BuildConfiguration
MSBuild configuration. Valid choices are Debug and Release.
.PARAMETER TFM
MSBuild target frameworks, see https://docs.microsoft.com/en-us/dotnet/standard/frameworks#supported-target-frameworks
Default values are: net462, net6.0 (net35 is currently not used but kept for legacy purposes)
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

    [Parameter(HelpMessage = "MSBuild configuration. Valid choices are Debug and Release.")]  
    [ValidateSet('Debug', 'Release', IgnoreCase = $true, ErrorMessage="Value '{0}' is invalid. Try one of: '{1}'")]
    [string] $BuildConfiguration = 'Debug',

    [Parameter(HelpMessage = "MSBuild target frameworks, see https://docs.microsoft.com/en-us/dotnet/standard/frameworks#supported-target-frameworks")]
    [string[]]$TFM = @('net462', 'net6.0'),

    [Parameter(HelpMessage = 'Rebuilds the solution. Equivalent of clean + build')]
    [switch] $Rebuild,

    [Parameter(HelpMessage = 'Calculate coverage when running tests')]
    [switch] $WithCoverage,

    [Parameter(HelpMessage = 'Destination folder for the build artifacts. If not provided it is assumed to be ''.\build''')]
    [string] $StagingDir,

    [Parameter(HelpMessage = 'Publish folder for the build artifacts. If not provided it is assumed to be ''.\publish''')]
    [string] $PublishDir,

    [Parameter(HelpMessage = 'Project version')]
    [string] $Version,

    [Parameter(HelpMessage = 'CI build number')]
    [string] $BuildNumber
)


Set-StrictMode -Version latest

function Set-PSModules{
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

function Build-Matrix{
    <#
    .SYNOPSIS 
    Builds the project using 'MSBuild' for net462 or lower and 'dotnet build' for the rest and Rebuild switch (if provided)
    #>
    param(
        [Parameter(HelpMessage = 'Solution file to build (either .sln or .slnf')]
        [string] $SlnFile,

        [Parameter(HelpMessage = "MSBuild target frameworks, see https://docs.microsoft.com/en-us/dotnet/standard/frameworks#supported-target-frameworks")]
        [string[]] $TargetFrameworks,
        
        [Parameter(HelpMessage = 'Path to standard MS Build, for .NET Framework not to ''dotnet'' or ''dotnet msbuild''')]
        [string] $MSBuildPath,
        
        [Parameter(HelpMessage = "MSBuild configuration. Valid choices are Debug and Release.")]  
        [ValidateSet('Debug', 'Release', IgnoreCase = $true, ErrorMessage="Value '{0}' is invalid. Try one of: '{1}'")]
        [string] $WithBuildConfiguration = 'Debug',
        
        [Parameter(HelpMessage = 'Rebuilds the solution. Equivalent of clean + build')]
        [switch] $WithRebuild,
        
        [Parameter(HelpMessage = 'MS Build paralelism. Defaults to 3')]
        [int] $WithParallelism = 3,
        
        [Parameter(HelpMessage = 'MS Build verbosity. Valid choices are: q[uiet], m[inimal], n[ormal] (default), d[etailed], and diag[nostic]')]
        [ValidateSet('q', 'm', 'n', 'd', 'diag', 'quiet', 'minimal', 'normal', 'detailed', 'diagnostic', IgnoreCase = $false, ErrorMessage="Value '{0}' is invalid. Try one of: '{1}'")]
        [string] $WithVerbosity = 'm'
    )

    Write-Output '[Build] Starting the build of NAnt2 project'
    if($WithRebuild){
        $buildTarget = "Rebuild"
    }
    else {
        $buildTarget = "Build"
    }
    
    #exec { & (Join-Path $TOOLS_DIR "NuGet.exe") restore (Join-Path $BuildRoot "NAnt.sln") }

    #for net-2.0, net-3.5 MSBuild is required so we'll use it for all .NET Framework versions lower than .NET 4.6.2
    #see https://github.com/dotnet/msbuild/discussions/7590
    $filteredTFM = $TargetFrameworks.Where({ $_ -lt 'net462'})
    $filteredTFM
    if($null -ne $filteredTFM -and $filteredTFM.Count -ge 1)
    {
        $buildFrameworks = $filteredTFM -join ";"
        Write-Build Blue "[Build] Building .NET Framework targets: $buildFrameworks"

        foreach($targetFramework in $filteredTFM)
        {
            Write-Output "[Build $targetFramework] Executing MSBuild -t:Restore"
            exec { & $MSBuildPath $SlnFile /target:Restore /property:Configuration=$WithBuildConfiguration /property:WarningLevel=0 /property:TargetFramework=$targetFramework /maxCpuCount:$WithParallelism /verbosity:$WithVerbosity /nodeReuse:true }

            Write-Output "[Build $targetFramework] Executing MSBuild -t:$buildTarget"
            exec { & $MSBuildPath $SlnFile /target:$buildTarget /property:Configuration=$WithBuildConfiguration /property:WarningLevel=0 /property:TargetFramework=$targetFramework /maxCpuCount:$WithParallelism /verbosity:$WithVerbosity /nodeReuse:false /nodeReuse:false}        
        }
    }

    $filteredTFM = $TargetFrameworks.Where({ $_ -cge 'net462'})
    $filteredTFM
    if($null -ne $filteredTFM -and $filteredTFM.Count -ge 1)
    {
        $buildFrameworks = $filteredTFM -join ";"
        Write-Build Blue "[Build] Building .NET Core / .NET targets: $buildFrameworks"

        Write-Output "[Build] dotnet restore"
        exec { & dotnet restore }

        if($WithRebuild)
        {
            Write-Output "[Build] dotnet build --no-incremental -p:TargetFrameworks=$buildFrameworks"
            exec { & dotnet build $SlnFile --no-incremental -c $WithBuildConfiguration -v $WithVerbosity -p:WarningLevel=0 -m:$WithParallelism -- -p:TargetFrameworks="$buildFrameworks" }
        }
        else{
            Write-Output "[Build] dotnet build -p:TargetFrameworks=$buildFrameworks"
            exec { & dotnet build $SlnFile -c $WithBuildConfiguration -v $WithVerbosity -p:WarningLevel=0 -m:$WithParallelism -- -p:TargetFrameworks="$buildFrameworks" }
        }
        
    }
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
if(-not $StagingDir) {
    $StagingDir = Join-Path $BuildRoot "build"
}
if(-not (Test-Path -LiteralPath $StagingDir))
{
    New-Item $StagingDir -ItemType Directory -Force
}
if(-not $PublishDir) {
    $PublishDir = Join-Path $BuildRoot "publish"
}
if(-not (Test-Path -LiteralPath $PublishDir))
{
    New-Item $PublishDir -ItemType Directory -Force
}

$SRC_DIR = Join-Path $BuildRoot "src"
$STAGING_DIR = $StagingDir
$BOOTSTRAP_DIR = Join-Path $STAGING_DIR "bootstrap"
$PUBLISH_DIR = $PublishDir

$TOOLS_DIR = Join-Path $BuildRoot "tools"
$REPORTS_DIR = Join-Path $BuildRoot "reports"

$VSWHERE_EXE = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if(-not (Test-Path -LiteralPath $VSWHERE_EXE)) {
    $VSWHERE_EXE = Join-Path $TOOLS_DIR "wswhere.exe"
}
$MSBUILD_EXE = "msbuild"
if($IsWindows) {
    $MSBUILD_EXE = & $VSWHERE_EXE -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | Select-Object -first 1
}

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
    Staging directory: $STAGING_DIR,
    Boostrap directory: $BOOTSTRAP_DIR,
    Publish directory: $PUBLISH_DIR,
    Tools directory: $TOOLS_DIR,
    Reports directory: $REPORTS_DIR,
    vswhere.exe path: $VSWHERE_EXE,
    msbuild.exe path: $MSBUILD_EXE"
    
    #determine MSBuild path if on Windows, see https://halfblood.pro/locate-msbuild-via-powershell-on-different-operating-systems-140757bb8e18
    if($IsWindows)
    {
        Set-PSModules 'VSSetup'
        $instance = Get-VSSetupInstance -All | Select-VSSetupInstance -Require 'Microsoft.Component.MSBuild' -Latest
        $installDir = $instance.installationPath
        Write-Host "Visual Studio is found at $installDir"
        $MSBUILD = $installDir + '\MSBuild\Current\Bin\MSBuild.exe'
        if (![System.IO.File]::Exists($MSBUILD))
        {
            $MSBUILD = (Get-ChildItem -Path $installDir -Filter MSBuild.exe -Recurse).FullName | Select-Object -First 1
            #$msBuild = $installDir + '\MSBuild\15.0\Bin\MSBuild.exe'
            if (![System.IO.File]::Exists($MSBUILD))
            {
                Write-Build Red "MSBuild could not be found. Build failed."
                exit 1
            }
            & $MSBUILD /version
        }
    }
    else{
        & $MSBUILD /version
    }
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

    # Make sure staging folder exists
    if ((Test-Path $BuildRoot) -and !(Test-Path $STAGING_DIR)) {
        Write-Output "[Init] Creating staging directory..."
        New-Item -Path $STAGING_DIR -Type Directory | Out-Null
    }

    # Make sure publish folder exists
    if ((Test-Path $BuildRoot) -and !(Test-Path $PUBLISH_DIR)) {
        Write-Output "[Init] Creating publish directory..."
        New-Item -Path $PUBLISH_DIR -Type Directory | Out-Null
    }

    # Make sure reports folder exists
    if ((Test-Path $BuildRoot) -and !(Test-Path $REPORTS_DIR)) {
        Write-Output "[Init] Creating reports directory..."
        New-Item -Path $REPORTS_DIR -Type Directory | Out-Null
    }
}

task Clean {
    <#
    .SYNOPSIS 
    Executes any cleanup required before building the project.
    #>

    Write-Output '[Clean] Cleaning staging directory and the obsolete boostrap folder'
    Get-ChildItem -Path $STAGING_DIR | Remove-Item -Recurse -Force -ErrorAction Ignore 
    Remove-Item (Join-Path $BuildRoot 'bootstrap') -Recurse -Force -ErrorAction Ignore 

    if (Test-Path $PUBLISH_DIR ) {
        Write-Output "[Clean] Cleaning publish directory..."
        Get-ChildItem -Path $PUBLISH_DIR | Remove-Item -Recurse -Force -ErrorAction Ignore
    }

    Write-Output '[Clean] Cleaning reports folder'
    if (Test-Path $REPORTS_DIR ) {
        Write-Output -Message "[Clean] Cleaning reports directory..."
        Get-ChildItem -Path $REPORTS_DIR -Exclude NDependOut | Remove-Item -Recurse -Force -ErrorAction Ignore
    }
}

task Deep-Clean Clean, {
    <#
    .SYNOPSIS 
    Executes default cleanup (Staging, publish and reports directories) and also cleans /bin and /obj folders
    #>

    Write-Output "[Deep-Clean] Cleaning /bin and /obj folders from $SRC_DIR and $TOOLS_DIR"
    Get-ChildItem $SRC_DIR -Include bin,obj -Recurse | Remove-Item -Recurse -Force -ErrorAction Ignore
    Get-ChildItem $TOOLS_DIR -Include bin,obj -Recurse | Remove-Item -Recurse -Force -ErrorAction Ignore
}

task Init-Bootstrap{
    Write-Output '[Init-Bootstrap] Start task'

    <#
    New-Item -Path $BOOTSTRAP_DIR -ItemType Directory -Force
    Copy-Item -Path (Join-Path $BuildRoot 'lib') -Destination (Join-Path $BOOTSTRAP_DIR 'lib') -Recurse
    # Mono loads log4net before privatebinpath is set-up, so we need log4net in the same directory as NAnt.exe
    Copy-Item -Path (Join-Path $BuildRoot 'lib' 'common' 'neutral' 'log4net.dll') -Destination $BOOTSTRAP_DIR
    Copy-Item -Path (Join-Path $SRC_DIR 'NAnt.Console' 'App.config') -Destination $BOOTSTRAP_DIR
    #>
}

### Build-Bootstrap ###
task Build-Bootstrap {
    Write-Output '[Build-Bootstrap] Start task'

    $slnFile = switch ( $IsWindows ) {
        $true    { $(Join-Path $BuildRoot "NAnt2.bootstrap.win.slnf") }
        $false   { $(Join-Path $BuildRoot "NAnt2.bootstrap.slnf") }
    }

    Build-Matrix -SlnFile $slnFile -TargetFrameworks $TFM -MSBuildPath $MSBUILD -WithBuildConfiguration $BuildConfiguration -WithRebuild -WithParallelism $parallelism -WithVerbosity $verbosity
}

task Build Clean, Init, {
    <#
    .SYNOPSIS 
    Builds the project using 'MSBuild' for net462 or lower and 'dotnet build' for the rest and Rebuild switch (if provided)
    #>
    $slnFile = Join-Path $BuildRoot "NAnt2.sln"
    Build-Matrix -SlnFile $slnFile -TargetFrameworks $TFM -MSBuildPath $MSBUILD -WithBuildConfiguration $BuildConfiguration -WithRebuild -WithParallelism $parallelism -WithVerbosity $verbosity
}

#region Default Task
task . Build