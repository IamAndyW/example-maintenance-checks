<#
    This is the entrypoint into a CDM check which will performance common validation and set common configuration.
#>

$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

$targetTimeZone = Get-TimeZone -ListAvailable | Where-Object {$_.id -eq $env:CDM_DATE_TIMEZONE}
$script:checkDateTime = [System.TimeZoneInfo]::ConvertTime($([datetime]::ParseExact($(Get-Date -Format $env:CDM_DATE_FORMAT), $env:CDM_DATE_FORMAT, $null).ToUniversalTime()), $targetTimeZone)
$script:skipUntilDateTime = [datetime]::ParseExact($env:CDM_CHECK_SKIP_UNTIL, $env:CDM_DATE_FORMAT, $null)

Write-Host ("Check date: {0} {1}" -f $checkDateTime.ToString($env:CDM_DATE_FORMAT), $targetTimeZone.DisplayName)

# should check be skipped
if ($skipUntilDateTime -gt $checkDateTime) {
    Write-Warning ("Skipping CDM check until: {0}`n" -f $skipUntilDateTime.ToString($env:CDM_DATE_FORMAT))
    Write-Host "##vso[task.complete result=SucceededWithIssues]Skipping CDM check"

} else {
    # common configuration
    $pipelineConfiguration = @{
        checkConfigurationFilename = $env:CDM_CHECK_CONFIGURATION_FILENAME
        checkDisplayName = $env:SYSTEM_PHASEDISPLAYNAME
        checkDateFormat = $env:CDM_DATE_FORMAT
        checkDateTime = $checkDateTime
        stageName = $env:SYSTEM_STAGENAME
    }

    & ("./{0}/{1}" -f $env:SYSTEM_PHASENAME, $env:CDM_CHECK_POWERSHELL_FILENAME)
}

Pop-Location
