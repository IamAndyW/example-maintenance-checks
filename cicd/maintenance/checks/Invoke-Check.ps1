<#
    This is the entrypoint into the maintenance checks which will performance common validation and set common configuration.

    Check filename: '[check name]/[check basename].ps1'
    example: 'terraform/check.ps1'

    Check configuration filename: '[check name]/configuration.json
    example: 'terraform/configuration.json'

    Windows to IANA timezone mappings:
    https://www.unicode.org/cldr/charts/45/supplemental/zone_tzid.html    
#>

$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

$targetTimeZone = Get-TimeZone -ListAvailable | Where-Object {$_.id -eq $env:MAINTENANCE_DATE_TIMEZONE}
$script:checkDateTime = [System.TimeZoneInfo]::ConvertTime($([datetime]::ParseExact($(Get-Date -Format $env:MAINTENANCE_DATE_FORMAT), $env:MAINTENANCE_DATE_FORMAT, $null).ToUniversalTime()), $targetTimeZone)
$script:skipUntilDateTime = [datetime]::ParseExact($env:MAINTENANCE_CHECK_SKIP_UNTIL, $env:MAINTENANCE_DATE_FORMAT, $null)

Write-Host ("Check date: {0} {1}" -f $checkDateTime.ToString($env:MAINTENANCE_DATE_FORMAT), $targetTimeZone.DisplayName)

# should check be skipped
if ($skipUntilDateTime -gt $checkDateTime) {
    Write-Warning ("Skipping maintenance check until: {0}`n" -f $skipUntilDateTime.ToString($env:MAINTENANCE_DATE_FORMAT))
    Write-Host "##vso[task.complete result=SucceededWithIssues]Skipping maintenance check"

} else {
    # common configuration
    $externalConfiguration = @{
        checkConfigurationFilename = "configuration.json"
        checkName = $env:SYSTEM_PHASENAME
        checkDisplayName = $env:SYSTEM_PHASEDISPLAYNAME
        checkDateFormat = $env:MAINTENANCE_DATE_FORMAT
        checkDateTime = $checkDateTime
        stageName = $env:SYSTEM_STAGENAME
    }

    & ("./{0}/{1}" -f $externalConfiguration.checkName, $env:MAINTENANCE_CHECK_POWERSHELL_FILENAME)
}

Pop-Location
