Configuration ConfigureSqlServer
{
    param
    (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$DomainAdminCreds,

        [Parameter(Mandatory)] 
        [String]$DomainFQDN,

        [Int]$RetryCount = 60,
        [Int]$RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration, StorageDsc
    [String] $DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN)
    $Interface = Get-NetAdapter | Where-Object Name -Like "Ethernet*" | Select-Object -First 1
    $UserName = $DomainAdminCreds.UserName
    $InterfaceAlias = $($Interface.Name)
    [System.Management.Automation.PSCredential] $DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)
    [String] $ComputerName = Get-Content env:computername

    node localhost
    {
        LocalConfigurationManager 
        {
            ConfigurationMode  = "ApplyOnly"
            ActionAfterReboot  = 'ContinueConfiguration'
            RebootNodeIfNeeded = $true
        }

        WaitForDisk Disk2
        {
             DiskId = 2
             RetryIntervalSec = $RetryCount
             RetryCount = $RetryIntervalSec
        }

        Disk DataVolume
        {
             DiskId = 2
             DriveLetter = 'G'
             DependsOn = '[WaitForDisk]Disk2'
        }
    }
}