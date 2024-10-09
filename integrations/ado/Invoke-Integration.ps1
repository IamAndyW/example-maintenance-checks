
<#
    This is the entrypoint into the CDM check ADO integration which performs validation and sets common configuration.

    This script will invoke a custom PowerShell script for the ADO organisation, project and action
    Example: cdm/integrations/ado/ensonodigitaluk-sre/ADOWorkItem.ps1
#>

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

$adoConfiguration = @{
    checkName = $env:SYSTEM_PHASENAME
    configurationFilename = "configuration.yml"
    organisation = $env:ADO_ORGANISATION_NAME
    project = $env:ADO_PROJECT_NAME
    baseUrl = ("{0}/{1}/{2}" -f "https://dev.azure.com", $env:ADO_ORGANISATION_NAME, $env:ADO_PROJECT_NAME)
    clientName = $env:ADO_CLIENT_NAME
    accessToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($env:ADO_ACCESS_TOKEN)"))
    action = $env:ADO_ACTION
}

$script:integrationFileName = ("./{0}-{1}/{2}.ps1" -f $adoConfiguration.organisation, $adoConfiguration.project, $((Get-Culture).TextInfo.ToTitleCase($adoConfiguration.action)))

if (Test-Path -Path $integrationFileName) {
    & $integrationFileName
} else {
    throw ("Integration filename '{0}' cannot be found" -f $integrationFileName)
}

Pop-Location
