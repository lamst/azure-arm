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

        [Parameter(Mandatory)] 
        [String]$PrivateIP,

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

    $CertPwd = $DomainAdminCreds.Password
    $ClearPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertPwd))

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
        WindowsFeature ADTools 
        { 
            Name = "RSAT-AD-Tools"
            Ensure = "Present"
            IncludeAllSubFeature = $true
        }

        WindowsFeature ADPS 
        { 
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
            IncludeAllSubFeature = $true
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

        xCredSSP CredSSPServer 
        { 
            Ensure = "Present"
            Role = "Server"
            DependsOn = "[DnsServerAddress]DnsServerAddress" 
        }

        xCredSSP CredSSPClient 
        { 
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

        CertReq ADFSSiteCert
        {
            CARootName                = "$DomainNetbiosName-$ComputerName-CA"
            CAServerFQDN              = "$ComputerName.$DomainFQDN"
            Subject                   = "$AdfsSiteName.$DomainFQDN"
            FriendlyName              = "$AdfsSiteName.$DomainFQDN site certificate"
            KeyLength                 = '2048'
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = 'WebServer'
            AutoRenew                 = $true
            SubjectAltName            = "dns=certauth.$AdfsSiteName.$DomainFQDN&dns=$AdfsSiteName.$DomainFQDN"
            Credential                = $DomainAdminCredsQualified
            DependsOn = '[WaitForCertificateServices]WaitAfterADCSProvisioning'
        }

        CertReq ADFSSigningCert
        {
            CARootName                = "$DomainNetbiosName-$ComputerName-CA"
            CAServerFQDN              = "$ComputerName.$DomainFQDN"
            Subject                   = "$AdfsSiteName.Signing"
            FriendlyName              = "$AdfsSiteName Signing"
            KeyLength                 = '2048'
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = 'WebServer'
            AutoRenew                 = $true
            Credential                = $DomainAdminCredsQualified
            DependsOn = '[WaitForCertificateServices]WaitAfterADCSProvisioning'
        }

        CertReq ADFSDecryptionCert
        {
            CARootName                = "$DomainNetbiosName-$ComputerName-CA"
            CAServerFQDN              = "$ComputerName.$DomainFQDN"
            Subject                   = "$AdfsSiteName.Decryption"
            FriendlyName              = "$AdfsSiteName Decryption"
            KeyLength                 = '2048'
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = 'WebServer'
            AutoRenew                 = $true
            Credential                = $DomainAdminCredsQualified
            DependsOn = '[WaitForCertificateServices]WaitAfterADCSProvisioning'
        }

        xADUser CreateAdfsSvcAccount
        {
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DomainName = $DomainFQDN
            UserName = $AdfsSvcCreds.UserName
            Password = $AdfsSvcCreds
            Ensure = "Present"
            PasswordAuthentication = 'Negotiate'
            PasswordNeverExpires = $true
            DependsOn = "[CertReq]ADFSSiteCert", "[CertReq]ADFSSigningCert", "[CertReq]ADFSDecryptionCert"
        }

        Group AddAdfsSvcAccountToDomainAdminsGroup
        {
            GroupName ='Administrators'   
            Ensure = 'Present'             
            MembersToInclude= $AdfsSvcCredsQualified.UserName
            Credential = $DomainAdminCredsQualified    
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn = "[xADUser]CreateAdfsSvcAccount"
        }

        WindowsFeature AddADFS 
        { 
            Name = "ADFS-Federation"
            Ensure = "Present"
            DependsOn = "[Group]AddAdfsSvcAccountToDomainAdminsGroup" 
        }

        xDnsRecord AddADFSHostDNS 
        {
            Name = $AdfsSiteName
            Zone = $DomainFQDN
            DnsServer = $DCName
            Target = $PrivateIP
            Type = "ARecord"
            Ensure = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn = "[WindowsFeature]AddADFS"
        }

        File CertFolder
        {
            DestinationPath = "C:\Cert"
            Type = "Directory"
            Ensure = "Present"
        }

        SmbShare CertShare
        {
            Ensure = "Present"
            Name = "Cert"
            Path = "C:\Cert"
            FullAccess = @("Domain Admins", "Domain Computers")
            ReadAccess = @("Everyone")
            DependsOn = "[File]CertFolder"
        }

        xScript ExportCertificates
        {
            SetScript = 
            {
                $destinationPath = "C:\Cert"
                $adfsSiteCertName = "ADFS Site.pfx"
                $adfsSiteIssuerCertName = "ADFS Site Issuer.cer"
                Write-Verbose -Message "Exporting ADFS site / issuer certificates..."
                $siteCert = Get-ChildItem -Path "cert:\LocalMachine\My\" -DnsName "$using:AdfsSiteName.$using:DomainFQDN"
                $siteCert | Export-PfxCertificate -FilePath ([System.IO.Path]::Combine($destinationPath, $adfsSiteCertName)) -Password (ConvertTo-SecureString $using:ClearPwd -AsPlainText -Force)
                Get-ChildItem -Path "cert:\LocalMachine\Root\" | Where-Object {$_.Subject -eq  $siteCert.Issuer} | Select-Object -First 1 | Export-Certificate -FilePath ([System.IO.Path]::Combine($destinationPath, $adfsSiteIssuerCertName))
                Write-Verbose -Message "Public key of ADFS site /issuer certificate successfully exported"
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
            DependsOn = "[WindowsFeature]AddADFS", "[SmbShare]CertShare"
        }

        xScript EnableSignonPage
        {
            SetScript = 
            {
                Set-AdfsProperties –EnableIdpInitiatedSignonPage $true
                Write-Verbose -Message "Enabled signon page..."
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
            DependsOn = "[xScript]ExportCertificates"
        }

        cADFSFarm CreateADFSFarm
        {
            ServiceCredential = $AdfsSvcCredsQualified
            InstallCredential = $DomainAdminCredsQualified
            DisplayName = "$AdfsSiteName.$DomainFQDN"
            ServiceName = "$AdfsSiteName.$DomainFQDN"
            CertificateSubject = "$AdfsSiteName.$DomainFQDN"
            #CertificateThumbprint = $siteCert
            #GroupServiceAccountIdentifier = $AdfsSvcCredsQualified
            #SigningCertificateThumbprint = $signingCert
            #DecryptionCertificateThumbprint = $decryptionCert
            #CertificateName = "$AdfsSiteName.$DomainFQDN"
            #SigningCertificateName = "$AdfsSiteName.Signing"
            #DecryptionCertificateName = "$AdfsSiteName.Decryption"
            Ensure= 'Present'
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn = "[WindowsFeature]AddADFS"
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