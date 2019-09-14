Configuration ConfigureWAP
{
    param
    (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$DomainAdminCreds,

        [Parameter(Mandatory)] 
        [String]$CAName,

        [Parameter(Mandatory)] 
        [String]$DomainFQDN,

        [Parameter(Mandatory)]
        [String]$AdfsSiteName
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, ComputerManagementDsc, xPSDesiredStateConfiguration
    [String] $DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN)
    [System.Management.Automation.PSCredential] $DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)

    Node localhost
    {
        LocalConfigurationManager {            
            DebugMode          = 'All'
            ActionAfterReboot  = 'ContinueConfiguration'            
            ConfigurationMode  = 'ApplyOnly'            
            RebootNodeIfNeeded = $true
        }

        WindowsFeature ADPS {
            Ensure               = "Present"
            Name                 = "RSAT-AD-PowerShell"
            IncludeAllSubFeature = $true
        }

        WindowsFeature RemoteAcess {
            Ensure               = "Present"
            Name                 = "RSAT-RemoteAccess"
            IncludeAllSubFeature = $true
        }

        WindowsFeature Telnet {
            Ensure = "Present"
            Name   = "Telnet-Client"
        }

        WindowsFeature WebAppProxy {
            Ensure = "Present"
            Name   = "Web-Application-Proxy"
        }

        xScript ImportCertificateAndInstallWAP {
            SetScript = 
            {
                $Cred = $using:DomainAdminCredsQualified
                $PathToCert = "\\$using:CAName\Cert\*.pfx"
                $CertFile = Get-ChildItem -Path $PathToCert
                for ($File = 0; $File -lt $CertFile.Count; $File++)
                {
                    $CertPath = $CertFile[$File].FullName
                    Import-PfxCertificate -Exportable -Password $Cred.Password -CertStoreLocation "cert:\LocalMachine\My\" -FilePath $CertPath
                }

                $Subject = "$using:AdfsSiteName.$using:DomainFQDN"
                $Cert = Get-ChildItem -Path "cert:\LocalMachine\My\" -DnsName $Subject
                Install-WebApplicationProxy -FederationServiceTrustCredential $Cred -CertificateThumbprint $Cert.Thumbprint -FederationServiceName $Subject
            }
            GetScript =  
            {
                # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
                return @{ "Result" = "false" }
            }
            TestScript = 
            {
                # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
               return $false
            }
            DependsOn = "[WindowsFeature]WebAppProxy"
        }
    }
}

function Get-NetBIOSName {
    [OutputType([string])]
    param(
        [string]$DomainFQDN
    )

    if ($DomainFQDN.Contains('.')) {
        $length = $DomainFQDN.IndexOf('.')
        if ( $length -ge 16) {
            $length = 15
        }
        return $DomainFQDN.Substring(0, $length)
    }
    else {
        if ($DomainFQDN.Length -gt 15) {
            return $DomainFQDN.Substring(0, 15)
        }
        else {
            return $DomainFQDN
        }
    }
}