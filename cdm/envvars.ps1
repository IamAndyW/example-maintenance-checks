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

<#
    Static check variables:
    cdm\checks\[check name]pipeline_variables.yml
#>
$env:CDM_CHECK_SKIP_UNTIL = "04/10/2024 11:17:00"

<#
    Dynamic pipeline variables:
#>
$env:SYSTEM_STAGENAME = "nonprod"
$env:SYSTEM_PHASENAME = "aws_elastic_kubernetes_service"
$env:SYSTEM_PHASEDISPLAYNAME = "PESTER DESCRIBE NAME"


<#
    Sensative variables dot sourced from:
    cdm\envvars_sensative.ps1

    DO NOT COMMIT THIS FILE TO SOURCE CONTROL
#>
. ./envvars_sensative.ps1

#Get-ChildItem -Path Env:

# cls
# $a = (Get-Content -Path ".\checks\$env:SYSTEM_PHASENAME\configuration.yml" | ConvertFrom-Yaml).$env:SYSTEM_PHASENAME
# $x = (Get-Content -Path ".\checks\$env:SYSTEM_PHASENAME\configuration.json" | ConvertFrom-Json).$env:SYSTEM_PHASENAME

# $b = ($a.stages | Where-Object {$_.name -eq $env:SYSTEM_STAGENAME}).clusters
# $y = ($x.stages | Where-Object {$_.name -eq $env:SYSTEM_STAGENAME}).clusters


# $clusters = [System.Collections.ArrayList]@()

# foreach ($cluster in ($a.stages | Where-Object {$_.name -eq $env:SYSTEM_STAGENAME}).clusters) {

# $clusterObject = [ordered] @{
#     resourceGroupName = $cluster.resourceGroupName
#     resourceName = $cluster.resourceName
# }

# $cluster = New-Object PSObject -property $clusterObject
# $clusters.Add($cluster)
# }

# $clusters | gm
# ""
# $y | gm

# Compare-Object -ReferenceObject $clusters -DifferenceObject $y -PassThru
