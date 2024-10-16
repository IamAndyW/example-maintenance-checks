Push-Location -Path $PSScriptRoot

<#
    Static pipeline variables:
    cicd\ado\templates\variables\pipeline_variables.yml
#>
$env:CDM_DATE_FORMAT = "dd/MM/yyyy HH:mm"
$env:CDM_DATE_TIMEZONE = "GMT Standard Time" # Windows

<#
    Static ADO integration pipeline variables:
    cicd\ado\templates\variables\pipeline_variables.yml
#>
$env:ADO_ORGANISATION_NAME = "ensonodigitaluk"
$env:ADO_PROJECT_NAME = "sre"
$env:ADO_CLIENT_NAME = "The Gym Group"

$env:ADO_ACTION = "CreateWorkItem"

<#
    Static check variables:
    cdm\checks\[check name]pipeline_variables.yml
#>
$env:CHECK_SKIP_UNTIL = "16/10/2024 11:40"

<#
    Task action
#>
$env:TASK_ACTION = "StartAKS"

<#
    Dynamic pipeline variables:
#>
$env:SYSTEM_STAGENAME = "nonprod"
$env:SYSTEM_STAGEDISPLAYNAME = "NONPROD"

$env:SYSTEM_PHASENAME = "azure_kubernetes_service"
$env:SYSTEM_PHASEDISPLAYNAME = "Azure Kubernetes Service"

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
