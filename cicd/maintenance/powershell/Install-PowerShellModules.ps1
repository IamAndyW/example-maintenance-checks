[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [array]
    $modules
)

foreach ($module in $modules) {
    Write-Host ("Module: {0}" -f $module)
    if ($null -eq (Get-Module -Name $module -ListAvailable)) {
        Write-Host ("Installing module") -ForegroundColor Yellow
        Install-Module -Name $module -Scope CurrentUser -Repository PSGallery -Force
    } else {
        Write-Host ("Module already installed") -ForegroundColor Yellow
    }
}
