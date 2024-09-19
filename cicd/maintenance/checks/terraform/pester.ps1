param (
    [Parameter(Mandatory = $true)]
    [hashtable] $runtimeConfiguration
)

BeforeDiscovery {
    $discovery = (Get-ChildItem -Directory).Name
} 

Describe $((Get-Culture).TextInfo.ToTitleCase($(Split-Path -Path $PSScriptRoot -Leaf).Replace('_', ' '))) {

    Context "Required Version" {

        BeforeEach {
            Push-Location -Path $_ 
        }

        # // START of tests //
        It "'terraform init' should return an Exit Code of 0" -ForEach $discovery {            
            terraform init
            $LASTEXITCODE | Should -Be 0 
        }
        # // END of tests //

        AfterEach {
            Write-Host ("`nVersion constraint in directory {0}: {1}`n" -f $_, $((Get-Content -Path '.\versions.tf' | Select-String -Pattern "required_version").ToString().TrimStart()))
            Pop-Location 
        }

        AfterAll {
            Write-Host ("`nInstalled Terraform version: {0}`n" -f $(terraform --version))
        }
    }
}
