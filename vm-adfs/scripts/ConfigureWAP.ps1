Configuration ConfigureWAP
{
    param
    (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$DomainAdminCreds,

        [Parameter(Mandatory)] 
        [String]$DNSServer,

        [Parameter(Mandatory)] 
        [String]$CAName,

        [Parameter(Mandatory)] 
        [String]$DomainFQDN,

        [Parameter(Mandatory)]
        [String]$AdfsSiteName
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, ComputerManagementDsc, NetworkingDsc, xPSDesiredStateConfiguration
    [String] $DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN)
    $Interface = Get-NetAdapter | Where-Object Name -Like "Ethernet*" | Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    $CertPath = "C:\Cert"
    [System.Management.Automation.PSCredential] $DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)

    Node localhost
    {
        LocalConfigurationManager {            
            DebugMode          = 'All'
            ActionAfterReboot  = 'ContinueConfiguration'            
            ConfigurationMode  = 'ApplyOnly'            
            RebootNodeIfNeeded = $true
        }

        #**********************************************************
        # Initialization of VM
        #**********************************************************
        WindowsFeature ADPS 
        {
            Ensure               = "Present"
            Name                 = "RSAT-AD-PowerShell"
            IncludeAllSubFeature = $true
        }

        WindowsFeature RemoteAcess 
        {
            Ensure               = "Present"
            Name                 = "RSAT-RemoteAccess"
            IncludeAllSubFeature = $true
        }

        WindowsFeature Telnet 
        {
            Ensure = "Present"
            Name   = "Telnet-Client"
        }

        WindowsFeature DnsTools 
        { 
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

        WindowsFeature WebAppProxy 
        {
            Ensure = "Present"
            Name   = "Web-Application-Proxy"
        }

        File CopyCert 
        {
            SourcePath = "\\$CAName.$DomainFQDN\Cert"
            DestinationPath = "$CertPath"
            Type = "Directory"
            Recurse = $true
            Ensure = "Present"
            Credential = $DomainAdminCredsQualified
            DependsOn = "[DnsServerAddress]DnsServerAddress"
        }

        xScript ImportCertificateAndInstallWAP 
        {
            SetScript = 
            {
                $Cred = $using:DomainAdminCredsQualified
                $PathToCert = "$using:CertPath\*.*"
                $CertFiles = Get-ChildItem -Path $PathToCert
                foreach ($CertFile in $CertFiles)
                {
                    Write-Verbose -Message "Certificate: $CertFile.FullName"
                }


                $PathToCert = "$using:CertPath\*.cer"
                $CertFiles = Get-ChildItem -Path $PathToCert
                foreach ($CertFile in $CertFiles)
                {
                    Write-Verbose -Message "Importing root certificate..."
                    $CertPath = $CertFile.FullName
                    Import-Certificate -CertStoreLocation "cert:\LocalMachine\Root\" -FilePath $CertPath
                }
                
                $PathToCert = "$using:CertPath\*.pfx"
                $CertFiles = Get-ChildItem -Path $PathToCert
                foreach ($CertFile in $CertFiles)
                {
                    Write-Verbose -Message "Importing certificate..."
                    $CertPath = $CertFile.FullName
                    Import-PfxCertificate -Exportable -Password $Cred.Password -CertStoreLocation "cert:\LocalMachine\My\" -FilePath $CertPath
                }

                # $Subject = "$using:AdfsSiteName.$using:DomainFQDN"
                # $Cert = Get-ChildItem -Path "cert:\LocalMachine\My\" -DnsName $Subject
                # Install-WebApplicationProxy -FederationServiceTrustCredential $using:DomainAdminCreds -CertificateThumbprint $Cert.Thumbprint -FederationServiceName $Subject
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
            DependsOn = "[WindowsFeature]WebAppProxy", "[DnsServerAddress]DnsServerAddress", "[File]CopyCert"
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