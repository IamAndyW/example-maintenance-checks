<#
    This is the entrypoint into the maintenance checks which will performance common validation and set common configuration.

    Check filename: '[check name]/[check basename].ps1'
    example: 'terraform/check.ps1'

    Check configuration filename: '[check name]/[check basename]_configuration.json
    example: 'terraform/check_configuration.json'
#>

$ErrorActionPreference = "Stop"

$script:checkDateTime = [datetime]::ParseExact($(Get-Date -Format $env:MAINTENANCE_CHECK_DATE_FORMAT), $env:MAINTENANCE_CHECK_DATE_FORMAT, $null).ToUniversalTime()
Write-Host ("Check date: {0} ({1})" -f $checkDateTime.ToString($env:MAINTENANCE_CHECK_DATE_FORMAT), $checkDateTime.Kind)

Push-Location -Path $PSScriptRoot

# should check be skipped
$script:skipUntilDateTime = [datetime]::ParseExact($env:MAINTENANCE_CHECK_SKIP_UNTIL, $env:MAINTENANCE_CHECK_DATE_FORMAT, $null).ToUniversalTime()

if ($skipUntilDateTime -gt $checkDateTime) {
    Write-Warning ("Skipping maintenance check until: {0} ({1})`n" -f $skipUntilDateTime.ToString($env:MAINTENANCE_CHECK_DATE_FORMAT), $skipUntilDateTime.Kind)
    Write-Host "##vso[task.complete result=SucceededWithIssues]Skipping maintenance check"

} else {

    # global runtime configuration
    $runtimeConfiguration = @{
        checkConfigurationFilename = ("{0}_configuration.json" -f $env:MAINTENANCE_SCRIPT_BASENAME)
        checkName = $env:SYSTEM_PHASENAME
        checkDisplayName = $env:SYSTEM_PHASEDISPLAYNAME
        checkDateFormat = $env:MAINTENANCE_CHECK_DATE_FORMAT
        checkDateTime = $checkDateTime
        stageName = $env:SYSTEM_STAGENAME
    }

    & ("./{0}/{1}" -f $runtimeConfiguration.checkName, $env:MAINTENANCE_CHECK_POWERSHELL_FILENAME)
}

Pop-Location
