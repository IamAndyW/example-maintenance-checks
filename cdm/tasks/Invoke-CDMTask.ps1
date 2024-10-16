<#
    This is the entrypoint into a CDM tasks which performs common validation and sets common configuration.

    This script will invoke a custom PowerShell script for the task
    Example: cdm/tasks/azure_kuberenetes_service/task.ps1
#>

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

$targetTimeZone = Get-TimeZone -ListAvailable | Where-Object {$_.id -eq $env:CDM_DATE_TIMEZONE}
$script:dateTime = [System.TimeZoneInfo]::ConvertTime($([datetime]::ParseExact($(Get-Date -Format $env:CDM_DATE_FORMAT), $env:CDM_DATE_FORMAT, $null).ToUniversalTime()), $targetTimeZone)

Write-Information -MessageData ("Task date: {0} {1}" -f $dateTime.ToString($env:CDM_DATE_FORMAT), $targetTimeZone.DisplayName)

$script:taskFileName = ("./{0}/{1}" -f $env:SYSTEM_PHASENAME, "task.ps1")

if (Test-Path -Path $taskFileName) {
    $parentConfiguration = @{
        configurationFilename = "configuration.yml"
        displayName = $env:SYSTEM_PHASEDISPLAYNAME
        stageName = $env:SYSTEM_STAGENAME
        configurationResourceTagName = "cdm_task_configuration"
        action = $env:TASK_ACTION
        taskDirectory = ("{0}/{1}" -f $env:CDM_TASKS_DIRECTORY, $env:SYSTEM_PHASENAME)
    }

    & $taskFileName
} else {
    throw ("Task filename '{0}' cannot be found" -f $taskFileName)
}

Pop-Location
