configuration ConfigureADFS
{
    param
    (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$DomainAdminCreds,

        [Parameter(Mandatory)] 
        [System.Management.Automation.PSCredential]$AdfsSvcCreds,

        [Parameter(Mandatory)] 
        [String]$DNSServer,

        [Parameter(Mandatory)] 
        [String]$DomainFQDN,

        [Parameter(Mandatory)] 
        [String]$DCName,

        [String]$AdfsSiteName = "fs1",
        [Int]$RetryCount = 20,
        [Int]$RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName ComputerManagementDsc, xActiveDirectory, xCredSSP, NetworkingDsc, PSDesiredStateConfiguration, xPSDesiredStateConfiguration, ActiveDirectoryCSDsc, CertificateDsc, xPendingReboot, cADFS, xDnsServer
    [String] $DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN)
    $Interface = Get-NetAdapter | Where-Object Name -Like "Ethernet*" | Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    [System.Management.Automation.PSCredential] $DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)
    [System.Management.Automation.PSCredential] $AdfsSvcCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($AdfsSvcCreds.UserName)", $AdfsSvcCreds.Password)
    [String] $ComputerName = Get-Content env:computername

    Node localhost
    {
        LocalConfigurationManager {
            ConfigurationMode  = "ApplyOnly"
            ActionAfterReboot  = 'ContinueConfiguration'
            RebootNodeIfNeeded = $true
        }

        #**********************************************************
        # Initialization of VM
        #**********************************************************
        WindowsFeature ADTools { 
            Name = "RSAT-AD-Tools"
            Ensure = "Present"
            IncludeAllSubFeature = $true
        }

        WindowsFeature ADPS { 
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
            IncludeAllSubFeature = $true
        }

        WindowsFeature DnsTools { 
            Name = "RSAT-DNS-Server"
            Ensure = "Present"
        }

        DnsServerAddress DnsServerAddress
        {
            Address        = $DNSServer
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn      = "[WindowsFeature]ADPS"
        }

        xCredSSP CredSSPServer { 
            Ensure = "Present"
            Role = "Server"
            DependsOn = "[DnsServerAddress]DnsServerAddress" 
        }

        xCredSSP CredSSPClient { 
            Ensure = "Present"
            Role = "Client"
            DelegateComputers = "*.$DomainFQDN", "localhost"
            DependsOn = "[xCredSSP]CredSSPServer" 
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