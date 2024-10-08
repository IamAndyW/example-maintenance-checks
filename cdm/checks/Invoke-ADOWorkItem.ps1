
$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

$adoConfiguration = @{
    collectionURI = $env:ADO_WORKITEM_COLLECTION_URI
    project = $env:ADO_WORKITEM_PROJECT_NAME
    accessToken = $env:ADO_ACCESS_TOKEN
}

$adoConfiguration.Add('baseURL',  ("{0}{1}" -f $adoConfiguration.collectionURI, $adoConfiguration.project))

& ("./{0}" -f $env:ADO_WORKITEM_POWERSHELL_FILENAME)

Pop-Location
