Push-Location -Path $PSScriptRoot

<#
    Static pipeline variables:
    cicd\ado\templates\variables\pipeline_variables.yml
#>
$env:CDM_DATE_FORMAT = "dd/MM/yyyy HH:mm:ss"
$env:CDM_DATE_TIMEZONE = "GMT Standard Time" # Windows

$env:CDM_CHECK_SCRIPT_BASENAME = "check"
$env:CDM_CHECK_POWERSHELL_FILENAME = "check.ps1"
$env:CDM_CHECK_CONFIGURATION_FILENAME = "configuration.yml"
$env:CDM_CHECK_RESULT_FILENAME = "check_results.xml"

$env:CDM_TASK_SCRIPT_BASENAME = "task"
$env:CDM_TASK_POWERSHELL_FILENAME = "task.ps1"

$env:ADO_CLIENT_NAME = "The Gym Group"
$env:ADO_COLLECTION_URI = "https://dev.azure.com/ediamandyw/"
$env:ADO_PROJECT_NAME = "sre"

$env:SYSTEM_COLLECTIONURI = "https://dev.azure.com/ediamandyw/"

<#
    Static check variables:
    cdm\checks\[check name]pipeline_variables.yml
#>
$env:CDM_CHECK_SKIP_UNTIL = "04/10/2024 11:17:00"

<#
    Dynamic pipeline variables:
#>
$env:SYSTEM_DEFINITIONNAME = "The Gym Group CDM Checks" 
$env:SYSTEM_STAGENAME = "nonprod"
$env:SYSTEM_STAGEDISPLAYNAME = "NONPROD"
$env:SYSTEM_PHASENAME = "terraform"
$env:SYSTEM_PHASEDISPLAYNAME = "Terraform"

$env:BUILD_BUILDID = "6982"
$env:BUILD_BUILDNUMBER = "2024.10.04.6"
$env:SYSTEM_STAGEID = "02cfcda7-55c4-5d00-5661-16255c29a59f"
$env:SYSTEM_JOBID = "ea0f9399-290c-5137-7726-029e7d80bd1f"

<#
    Sensative variables dot sourced from:
    cdm\envvars_sensative.ps1

    DO NOT COMMIT THIS FILE TO SOURCE CONTROL
#>
. ./envvars_sensative.ps1

#Get-ChildItem -Path Env:

cls
