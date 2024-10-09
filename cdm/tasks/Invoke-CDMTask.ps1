<#
    This is the entrypoint into the CDM tasks which will performance common validation and set common configuration.
#>

$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

$targetTimeZone = Get-TimeZone -ListAvailable | Where-Object {$_.id -eq $env:CDM_DATE_TIMEZONE}
$script:taskDateTime = [System.TimeZoneInfo]::ConvertTime($([datetime]::ParseExact($(Get-Date -Format $env:CDM_DATE_FORMAT), $env:CDM_DATE_FORMAT, $null).ToUniversalTime()), $targetTimeZone)

Write-Information -MessageData ("task date: {0} {1}" -f $taskDateTime.ToString($env:CDM_DATE_FORMAT), $targetTimeZone.DisplayName)

# common configuration
$pipelineConfiguration = @{
    taskConfigurationFilename = "configuration.json"
    taskName = $env:SYSTEM_PHASENAME
    taskDisplayName = $env:SYSTEM_PHASEDISPLAYNAME
    taskDateFormat = $env:CDM_DATE_FORMAT
    taskDateTime = $taskDateTime
    taskConfigurationResourceTagName = "CDM_configuration"
    stageName = $env:SYSTEM_STAGENAME
}

& ("./{0}/{1}" -f $pipelineConfiguration.taskName, $env:CDM_TASK_POWERSHELL_FILENAME)

Pop-Location
