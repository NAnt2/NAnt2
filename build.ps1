<#
.SYNOPSIS
NAnt2 build script.

.DESCRIPTION
Build script for NAnt2
.PARAMETER Tasks
One or more execution tasks(s), similar to NAnt or Cake targets as a string of tasks divided by comma
.PARAMETER BuildConfiguration
MSBuild configuration. Valid choices are Debug and Release.
.PARAMETER Rebuild
Rebuilds the solution. Default is to do a simple build.
.PARAMETER WithCoverage
Includes coverage when running tests
.PARAMETER StagingDir
Destination folder for staging build artifacts

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

    [Parameter(HelpMessage = 'Rebuilds the solution. Equivalent of clean + build')]
    [switch] $Rebuild,

    [Parameter(HelpMessage = 'Includes coverage when running tests')]
    [switch] $WithCoverage,

    [Parameter(HelpMessage = 'Destination folder for the build artifacts. If not provided it is assumed to be ''.\build''')]
    [string] $StagingDir,

    [Parameter(HelpMessage = 'Project version')]
    [string] $Version,

    [Parameter(HelpMessage = 'CI build number')]
    [string] $BuildNumber
)


Set-StrictMode -Version latest

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
if(-not $StagingDir)
{
    $StagingDir = Join-Path $BuildRoot "build"
}
$BOOTSTRAP_DIR = Join-Path $StagingDir "bootstrap"
$SRC_DIR = Join-Path $BuildRoot "src"

#####################################################
#      initialization: before build
#####################################################
Enter-Build {
    Write-Host "Initialization before build"
    <#
    ### initialization: other modules
    ##################################
    $requiredModules = @('Resolve-MSBuild')
    $policy = (Get-PSRepository PSGallery).InstallationPolicy
    try{
        Get-Module | Where-Object -Property Name -eq -Value 'AWSPowerShell' | Remove-Module
        foreach ($module in $requiredModules) {
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
    #>
}

#####################################
#          Tasks
#####################################
### Clean ###
task Clean{
    Write-Build Blue "Cleaning $StagingDir and the obsolete boostrap folder"
    Get-ChildItem -Path $StagingDir | Remove-Item -Recurse -Force
    Remove-Item (Join-Path $BuildRoot 'bootstrap') -Recurse -Force
}

### Initialize-Bootstrap ###
task Initialize-Bootstrap Clean{
    New-Item -ItemType Directory -Force -Path $BOOTSTRAP_DIR
    Copy-Item -Path (Join-Path $BuildRoot 'lib') -Destination (Join-Path $BOOTSTRAP_DIR 'lib') -Recurse
    # Mono loads log4net before privatebinpath is set-up, so we need log4net in the same directory as NAnt.exe
    Copy-Item -Path (Join-Path $BuildRoot 'lib' 'common' 'neutral' 'log4net.dll') -Destination $BOOTSTRAP_DIR
    Copy-Item -Path (Join-Path $SRC_DIR 'NAnt.Console' 'App.config') -Destination $BOOTSTRAP_DIR
}

### Build-Bootstrap ###
task Build-Bootstrap{
    
}