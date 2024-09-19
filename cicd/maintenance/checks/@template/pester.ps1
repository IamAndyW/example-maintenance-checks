param (
    [Parameter(Mandatory = $true)]
    [hashtable] $runtimeConfiguration
)

BeforeDiscovery {} 

Describe $((Get-Culture).TextInfo.ToTitleCase($(Split-Path -Path $PSScriptRoot -Leaf).Replace('_', ' '))) {
    
    Context "TODO" {
        
        # // START of tests //
        It "TODO" {

        }
        # // END of tests //
    }
}
