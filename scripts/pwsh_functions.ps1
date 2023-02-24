function Set-PSModules {
    <#
    .SYNOPSIS
    Installs from PSGallery and/or loads given powershell modules in current user scope.
    .PARAMETER Modules
    List of modules to install or load
    .PARAMETER AllowPrerelease
    Allow instalation of prereleased powershell modules.
    .EXAMPLE
    $requiredModules = @('AWS.Tools.SecretsManager', 'dbatools')
    Set-PSModules -Modules $requiredModules
    #>
    param(
        [Parameter(HelpMessage = ' List of modules to install or load')]
        [string[]]$Modules,
        [Parameter(HelpMessage = 'Allow instalation of prereleased powershell modules')]
        [switch]$AllowPrerelease = $false
    )

    $policy = (Get-PSRepository PSGallery).InstallationPolicy
    try{
        foreach ($module in $Modules) {
            if (Get-Module -ListAvailable -Name $module) {
                Write-Host "$module module exists"
            } 
            else {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                Install-Module $module `
                    -Scope CurrentUser `
                    -Force `
                    -Repository PSGallery `
                    -AcceptLicense `
                    -SkipPublisherCheck `
                    -AllowPrerelease:$AllowPrerelease `
                    -Verbose
            }

            Import-Module $module
        }
    }
    finally{
        Set-PSRepository PSGallery -InstallationPolicy $policy
    }
}