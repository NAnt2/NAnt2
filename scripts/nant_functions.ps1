function Invoke-NAnt {
    <#
    .SYNOPSIS
    Invokes NAnt from bootstrap folder to execute the given target
    .PARAMETER BuildFile
    Path to NAnt build file
    .PARAMETER Framework
    NAnt target framework
    .PARAMETER PrjVersion
    Project version
    .PARAMETER PrjBuildNumber
    Project build number
    .PARAMETER BuildMode
    MSBuild configuration. Valid choices are Debug and Release
    .PARAMETER NAntTarget
    NAnt target to execute
    #>
    param (
        [Parameter(HelpMessage = "Path to NAnt build file.")]  
        [string] $BuildFile,
        [Parameter(HelpMessage = "NAnt target framework.")]  
        [string] $Framework,
        [Parameter(HelpMessage = "Project version.")]  
        [string] $PrjVersion,
        [Parameter(HelpMessage = "Project build number.")]  
        [string] $PrjBuildNumber,
        [Parameter(HelpMessage = "MSBuild configuration. Valid choices are Debug and Release.")]  
        [string] $BuildMode,
        [Parameter(HelpMessage = "NAnt target.")]  
        [string] $NAntTarget
    )

    assert(Test-Path -LiteralPath $BuildFile) "Provided NAnt build file $BuildFile does not exist"

    # Leave build.number to the build file when none was given. Its default is
    # the number of days since 2000, which keeps the assembly version usable by
    # tooling that checks it - TeamCity's NAnt listener rejects a NAnt whose
    # NAnt.Core version has a Build field below 2311. Forcing a low number here
    # would override that default and produce a NAnt such tooling refuses.
    $buildNumberArg = [string]::IsNullOrWhiteSpace($PrjBuildNumber) ?
        @() : @("-D:build.number=$PrjBuildNumber")

    if($IsWindows) {
        & $(Join-Path $BOOTSTRAP_DIR 'NAnt.exe') `
            -j $(($BuildMode -eq 'Debug') ? '-debug+' : '') `
            -t:$Framework `
            -D:project.version=$PrjVersion `
            @buildNumberArg `
            -D:project.config=$($BuildMode.ToLower()) `
            -verbose `
            -f:$BuildFile `
            $NAntTarget
    }
    else {
        & mono $(Join-Path $BOOTSTRAP_DIR 'NAnt.exe') `
            -j $(($BuildMode -eq 'Debug') ? '-debug+' : '') `
            -t:$Framework `
            -D:project.version=$PrjVersion `
            @buildNumberArg `
            -D:project.config=$($BuildMode.ToLower()) `
            -verbose `
            -f:$BuildFile `
            $NAntTarget
    }
}