<#
    This is the entrypoint into a CDM check which performs common validation and sets common configuration.

    This script will invoke a custom PowerShell script for the ADO action, organisation and project
    Example: cdm/checks/terraform/check.ps1
#>

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

$script:targetTimeZone = Get-TimeZone -ListAvailable | Where-Object {$_.id -eq $env:CDM_DATE_TIMEZONE}
$script:dateTime = [System.TimeZoneInfo]::ConvertTime($([datetime]::ParseExact($(Get-Date -Format $env:CDM_DATE_FORMAT), $env:CDM_DATE_FORMAT, $null).ToUniversalTime()), $targetTimeZone)
$script:skipUntilDateTime = [datetime]::ParseExact($env:CDM_CHECK_SKIP_UNTIL, $env:CDM_DATE_FORMAT, $null)

Write-Information -MessageData ("Check date: {0} {1}" -f $dateTime.ToString($env:CDM_DATE_FORMAT), $targetTimeZone.DisplayName)

$script:checkFileName = ("./{0}/{1}" -f $env:SYSTEM_PHASENAME, "check.ps1")

if ($skipUntilDateTime -gt $dateTime) {
    Write-Warning ("Skipping CDM check until: {0}`n" -f $skipUntilDateTime.ToString($env:CDM_DATE_FORMAT))
    Write-Host "##vso[task.complete result=SucceededWithIssues]Skipping CDM check"
} elseif (Test-Path -Path $checkFileName) {
    $pipelineConfiguration = @{
        configurationFilename = "configuration.yml"
        displayName = $env:SYSTEM_PHASEDISPLAYNAME
        dateFormat = $env:CDM_DATE_FORMAT
        dateTime = $dateTime
        stageName = $env:SYSTEM_STAGENAME
    }

    & $checkFileName
} else {
    throw ("Check filename '{0}' cannot be found" -f $checkFileName)
}

Pop-Location
