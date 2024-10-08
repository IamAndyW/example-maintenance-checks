Function Link-ADOWorkItemToParent {
	
    [CmdletBinding()]
    param (

        [Parameter(Mandatory=$false)]
        [hashtable]$headers = @{"content-type" = "application/json-patch+json"},

        [Parameter(Mandatory=$true)]
        [ValidateScript({            
            If ([uri]::IsWellFormedUriString($_,[urikind]::Absolute)) {Return $true}
        })]
        [string]$baseURL,

        [Parameter(Mandatory=$false)]
        [string]$apiVersion = "7.1",

        [Parameter(Mandatory=$true)]
        [string]$systemAccessToken,
        
        [Parameter(Mandatory=$true)]
        [string]$wiId,

        [Parameter(Mandatory=$true)]
        [string]$wiParentId
    )

    $parameters = @{
        method = "PATCH"
        headers = $headers
    }

    $accessToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($systemAccessToken)"))
    $queryParameters = ("api-version={0}" -f $apiVersion)
    $bodyObject = @{
        op = "add"
        path = "/relations/-"
        from = $null
        value = @{
            rel = "System.LinkTypes.Hierarchy-Reverse"
            url = ("{0}/_apis/wit/workitems/{1}" -f $baseURL, $wiParentId)
        }
    }

    $body= ConvertTo-Json -InputObject @($bodyObject)

    $parameters.Add('uri', [URI]::EscapeUriString(("{0}/_apis/{1}?{2}" -f $baseURL, ("wit/workitems/{0}" -f $wiId), $queryParameters)))
    $parameters.headers.Add('Authorization', ("Basic {0}" -f $accessToken))
    $parameters.Add('body', $body)
    
    $response = Invoke-RestMethod @parameters | Write-Output | Select-Object -ExpandProperty url
    
    return $response
}
