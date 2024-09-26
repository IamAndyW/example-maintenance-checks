[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [array]
    $moduleNames
)

foreach ($moduleName in $moduleNames) {
    Write-Host ("`nModule name: {0}" -f $moduleName)
    
    $module = Get-Module -Name $moduleName -ListAvailable

    if ($null -eq $module) {
        Write-Host ("Installing module`n") -ForegroundColor Yellow
        Install-Module -Name $moduleName -Scope CurrentUser -PassThru -Repository PSGallery -Force
    } else {
        Write-Host ("Module already installed with version: {0}`n" -f $module.Version) -ForegroundColor Yellow
    }
}
