Push-Location -Path $PSScriptRoot

<#
    Static pipeline variables:
    cicd\build\ado\templates\variables\pipeline.yml
#>
$env:MAINTENANCE_CHECK_SCRIPT_BASENAME = "check"
$env:MAINTENANCE_CHECK_POWERSHELL_FILENAME = "check.ps1"
$env:MAINTENANCE_CHECK_RESULT_FILENAME = "check_results.xml"
$env:MAINTENANCE_DATE_FORMAT = "dd/MM/yyyy HH:mm:ss"
$env:MAINTENANCE_DATE_TIMEZONE = "GMT Standard Time" # Windows

<#
    Static check variables:
    cicd\build\ado\templates\variables\[check name].yml
#>
$env:MAINTENANCE_CHECK_SKIP_UNTIL = "01/10/2024 10:52:00"

<#
    Dynamic pipeline variables:
#>
$env:SYSTEM_STAGENAME = "nonprod"
$env:SYSTEM_PHASENAME = "github"
$env:SYSTEM_PHASEDISPLAYNAME = "PESTER DESCRIBE NAME"


<#
    Sensative variables dot sourced from:
    cicd\maintenance\envvars_sensative.ps1

    DO NOT COMMIT THIS FILE TO SOURCE CONTROL
#>
. ./envvars_sensative.ps1

#Get-ChildItem -Path Env:
