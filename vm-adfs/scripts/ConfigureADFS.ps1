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

        #**********************************************************
        # Join AD forest
        #**********************************************************
        xWaitForADDomain DscForestWait
        {
            DomainName           = $DomainFQDN
            RetryCount           = $RetryCount
            RetryIntervalSec     = $RetryIntervalSec
            DomainUserCredential = $DomainAdminCredsQualified
            DependsOn            = "[xCredSSP]CredSSPClient"
        }

        Computer DomainJoin
        {
            Name       = $ComputerName
            DomainName = $DomainFQDN
            Credential = $DomainAdminCredsQualified
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        xScript CreateWSManSPNsIfNeeded
        {
            SetScript =
            {
                # A few times, deployment failed because of this error:
                # "The WinRM client cannot process the request. A computer policy does not allow the delegation of the user credentials to the target computer because the computer is not trusted."
                # The root cause was that SPNs WSMAN/SP and WSMAN/sp.contoso.local were missing in computer account contoso\SP
                # Those SPNs are created by WSMan when it (re)starts
                # Restarting service causes an error, so creates SPNs manually instead
                # Restart-Service winrm

                # Create SPNs WSMAN/SP and WSMAN/sp.contoso.local
                $domainFQDN = $using:DomainFQDN
                $computerName = $using:ComputerName
                Write-Verbose -Message "Adding SPNs 'WSMAN/$computerName' and 'WSMAN/$computerName.$domainFQDN' to computer '$computerName'"
                setspn.exe -S "WSMAN/$computerName" "$computerName"
                setspn.exe -S "WSMAN/$computerName.$domainFQDN" "$computerName"
            }
            GetScript = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript = 
            {
                $computerName = $using:ComputerName
                $samAccountName = "$computerName$"
                if ((Get-ADComputer -Filter {(SamAccountName -eq $samAccountName)} -Property serviceprincipalname | Select-Object serviceprincipalname | Where-Object {$_.ServicePrincipalName -like "WSMAN/$computerName"}) -ne $null) {
                    # SPN is present
                    return $true
                }
                else {
                    # SPN is missing and must be created
                    return $false
                }
            }
            DependsOn="[Computer]DomainJoin"
        }

        #**********************************************************
        # Configure AD CS
        #**********************************************************
        WindowsFeature AddCertAuthority
        { 
            Name = "ADCS-Cert-Authority"
            Ensure = "Present"
            DependsOn = "[Computer]DomainJoin" 
        }

        WindowsFeature AddADCSManagementTools
        {
            Name = "RSAT-ADCS-Mgmt"
            Ensure = "Present"
            DependsOn = "[Computer]DomainJoin"
        }

        ADCSCertificationAuthority ADCS
        {
            IsSingleInstance = "Yes"
            CAType = "EnterpriseRootCA"
            Ensure = "Present"
            Credential = $DomainAdminCredsQualified
            DependsOn = "[WindowsFeature]AddCertAuthority"
        }

        #**********************************************************
        # Configure AD FS
        #**********************************************************
        WaitForCertificateServices WaitAfterADCSProvisioning
        {
            CAServerFQDN = "$ComputerName.$DomainFQDN"
            CARootName = "$DomainNetbiosName-$ComputerName-CA"
            DependsOn = '[ADCSCertificationAuthority]ADCS'
            PsDscRunAsCredential = $DomainAdminCredsQualified
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