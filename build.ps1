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

function Get-MsBuild{
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

    #& $msBuild_exe /version

    return $msBuild_exe
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
if(-not $PublishDir) {
    $PublishDir = Join-Path $BuildRoot "publish"
}
if(-not (Test-Path -LiteralPath $PublishDir))
{
    New-Item $PublishDir -ItemType Directory -Force
}

$SRC_DIR = Join-Path $BuildRoot "src"
$PUBLISH_DIR = $PublishDir

$TOOLS_DIR = Join-Path $BuildRoot "tools"
$REPORTS_DIR = Join-Path $BuildRoot "reports"

$MSBUILD = Get-MsBuild -ToolsDir $TOOLS_DIR

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
    Publish directory: $PUBLISH_DIR,
    Tools directory: $TOOLS_DIR,
    Reports directory: $REPORTS_DIR,
    msbuild.exe path: $MSBUILD"
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
    Executes default cleanup (Staging, publish and reports directories) and also cleans /bin and /obj folders
    #>

    Write-Output "[Deep-Clean] Cleaning /bin and /obj folders from $SRC_DIR, tests and $TOOLS_DIR"
    Get-ChildItem $SRC_DIR -Include bin,obj -Recurse | Remove-Item -Recurse -Force -ErrorAction Ignore
    Get-ChildItem (Join-Path $BuildRoot "tests") -Include bin,obj -Recurse | Remove-Item -Recurse -Force -ErrorAction Ignore
    Get-ChildItem $TOOLS_DIR -Include bin,obj -Recurse | Remove-Item -Recurse -Force -ErrorAction Ignore
}

task Build Clean, Init, {
    <#
    .SYNOPSIS 
    Builds the project using 'MSBuild' for net462 or lower and 'dotnet build' for the rest and Rebuild switch (if provided)
    #>
    $slnFile = Join-Path $BuildRoot "NAnt2.sln"
    Build-Matrix -SlnFile $slnFile -TargetFrameworks $TFM -MSBuildPath $MSBUILD -WithBuildConfiguration $BuildConfiguration -WithRebuild -WithParallelism $parallelism -WithVerbosity $verbosity
}

task Test {
    <#
    .SYNOPSIS 
    Runs tests and optionally calculates coverage
    #>
    Write-Output '[Test] Running the Woomio API v2 tests. Does not rebuild the project.'
    exec { & dotnet test --nologo --no-build --no-restore --framework net462 --configuration $BuildConfiguration --logger "console;verbosity=normal" --logger "trx;LogFileName=nant.test.trx" --results-directory $REPORTS_DIR -v n -- NUnit.TestOutputXml=$REPORTS_DIR }

    Write-Output "Test task exit code: $LastExitCode"
    assert($LastExitCode -eq 0) "At least one test failed"

    if($WithCoverage){
        Write-Output '[Test] Calculating code coverage. Does not rebuild the project.'
        #get path to Tests.dll
        $testsDll = Get-ChildItem -Filter NAnt.Tests.dll -Path tests\bin\$BuildConfiguration\net462 -Recurse -Depth 2
        # coverlet requires the ending slash for --output parameter or it fails to generate the right path where to put the coverage files
        $reportsPathWithEndingSlash = Join-Path $REPORTS_DIR $([IO.Path]::DirectorySeparatorChar)
        if(Test-Path $testsDll)
        {
        exec { & dotnet coverlet $($testsDll.FullName) --target "dotnet" --targetargs "test --no-build --no-restore --framework net462   --configuration:$BuildConfiguration" --include "[NAnt.*]*" --include "[NAntContrib]*" --exclude-by-attribute "Obsolete" --exclude-by-attribute "GeneratedCode" --exclude-by-attribute "CompilerGenerated" --skipautoprops --output $reportsPathWithEndingSlash --format opencover --format json --format cobertura --verbosity Detailed }
        }
        else {
            Write-Build Orange "[Test] No code coverage calculated. Tests dll not found in path tests\bin\$BuildConfiguration"
        }

        <#
        0 - Success.
        1 - If any test fails.
        2 - Coverage percentage is below threshold.
        3 - Test fails and also coverage percentage is below threshold.
        101 - General exception occurred during coverlet process.
        102 - Missing options or invalid arguments for coverlet process.#>
        assert($LastExitCode -eq 0) "At least one test failed"
    }    
}

task Stage {
    <#
    .SYNOPSIS 
    Gathers build artefacts for publishing
    #>

    foreach($targetFramework in $TFM)
    {
        Write-Output "[Stage] Staging build artefacts for $targetFramework"
        $stageDir = Join-Path $PUBLISH_DIR $targetFramework
        New-Item -Path $stageDir -Type Directory -Force | Out-Null
        
        if ($targetFramework -gt 'net48')
        {
            dotnet publish -c $BuildConfiguration -f $targetFramework -o $stageDir --no-build --no-self-contained
        }
        else {
            Copy-Item -Path (Join-Path $BuildRoot 'lib') -Exclude scvs.exe -Destination $stageDir -Recurse -Force
            Copy-Item -Path (Join-Path $SRC_DIR 'NAnt.Console' 'bin' $BuildConfiguration $targetFramework '*') -Destination $stageDir -Force -Exclude log4net.dll,ICSharpCode.SharpZipLib.dll,NAnt.MSBuild.dll,NAnt.MSBuild.pdb

            #override log4net and SharpZipLib from lib/common with latest from build
            # the reason lib/common contains older versions is to support net35 build (if needed)
            Copy-Item -Path (Join-Path $SRC_DIR 'NAnt.Console' 'bin' $BuildConfiguration $targetFramework '*') -Include log4net.dll,ICSharpCode.SharpZipLib.dll -Destination (Join-Path $stageDir 'lib' 'common' 'neutral') -Force
            
            #put NAnt.MSBuild in lib/extensions
            New-Item -Path (Join-Path $stageDir 'lib' 'extensions' 'common' 'neutral') -Type Directory -Force | Out-Null
            Copy-Item -Path (Join-Path $SRC_DIR 'NAnt.Console' 'bin' $BuildConfiguration $targetFramework 'NAnt.MSBuild.*') -Destination (Join-Path $stageDir 'lib' 'extensions' 'common' 'neutral') -Force

            #copy scvs.exe to main dir from lib/common
            Copy-Item -Path (Join-Path $BuildRoot 'lib' 'common' 'neutral' 'scvs.exe') -Destination $stageDir -Force
        }
    }
}

#region Default Task
task . Build