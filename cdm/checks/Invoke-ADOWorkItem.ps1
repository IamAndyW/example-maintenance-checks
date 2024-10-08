
$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

$adoConfiguration = @{
    collectionURI = $env:ADO_COLLECTION_URI
    project = $env:ADO_PROJECT_NAME
}

$adoConfiguration.Add('baseURL',  ("{0}{1}" -f $adoConfiguration.collectionURI, $adoConfiguration.project))

if ($adoConfiguration.collectionURI -eq $env:SYSTEM_COLLECTIONURI) {
    $adoConfiguration.Add('token', $env:SYSTEM_ACCESSTOKEN)
} else {
    $adoConfiguration.Add('token', $env:ADO_TOKEN)
}

switch ($adoConfiguration.baseURL) {

    "https://dev.azure.com/ensonodigitaluk/sre"  {

        & ("./{0}.ps1" -f "EDSRE-ADOWorkItem")
    }

    default {
        throw ("Cannot find ADO work item PowerShell script for the ADO: {0}" -f $adoConfiguration.baseURL)
    }
}

Pop-Location
