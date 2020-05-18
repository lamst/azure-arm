Configuration ConfigureWebServer
{
    param
    (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$ScriptRunAsCreds
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration, PSDesiredStateConfiguration

    [string] $PM2Home = "C:\etc\.pm2"

    node localhost
    {
        LocalConfigurationManager 
        {
            ConfigurationMode  = "ApplyOnly"
            ActionAfterReboot  = 'ContinueConfiguration'
            RebootNodeIfNeeded = $true
        }

        WindowsFeature InstallWebServer
        {
            Ensure = "Present"
            Name = "Web-Server"
        }

        WindowsFeature InstallManagementTools
        {
            Ensure = "Present"
            Name = "Web-Mgmt-Tools"
        }

        #**********************************************************
        # Download .NET Framework
        #**********************************************************
        File DownloadFolder
        {
            DestinationPath = "C:\Downloads"
            Type = "Directory"
            Ensure = "Present"
        }

        #**********************************************************
        # Install Node.js 8.9.4
        #**********************************************************
        xRemoteFile DownloadNodeJS
        {
            Uri = "https://nodejs.org/download/release/v8.9.4/node-v8.9.4-x64.msi"
            DestinationPath = "C:\Downloads\node-v8.9.4-x64.msi"
            MatchSource = $false
            DependsOn = "[File]DownloadFolder"
        }

        xPackage InstallNodeJS 
        {
            Name = "Node.js"
            ProductId = ""
            Arguments = "/qn /norestart /log C:\Downloads\nodejs-install.log"
            Path = "C:\Downloads\node-v8.9.4-x64.msi"
            DependsOn = "[WindowsFeature]InstallWebServer", "[xRemoteFile]DownloadNodeJS"
        }

        #**********************************************************
        # PM2 Home Directory
        #**********************************************************
        File PM2HomeDirectory
        {
            DestinationPath = $PM2Home
            Type = "Directory"
            Ensure = "Present"
        }

        xScript GrantPM2FullControlToLocalService
        {
            SetScript =
            {
                Write-Verbose -Message "Attempting to give LOCAL SERVICE FullControl acccess PM2 directory"
                $pm2Home = $using:PM2Home
                New-Item -ItemType Directory -Force -Path $pm2Home
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("LOCAL SERVICE", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
                $acl = Get-Acl -Path $pm2Home -ErrorAction Stop
                $acl.SetAccessRule($rule)
                Set-Acl -Path $pm2Home -AclObject $acl -ErrorAction Stop
                Write-Host "Successfully set FullControl permissions on $pm2Home"
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
            DependsOn="[File]PM2HomeDirectory"
        }

        #**********************************************************
        # Install PM2 Service
        #**********************************************************
        xScript InstallPM2Services
        {
            SetScript =
            {
                Write-Verbose -Message "Installing pm2 dependencies..."
                Start-Process -FilePath "C:\Program Files\nodejs\npm.cmd" -ArgumentList "install", "bufferutil", "-g" -Wait
                Start-Process -FilePath "C:\Program Files\nodejs\npm.cmd" -ArgumentList "install", "utf-8-validate", "-g" -Wait
                Start-Process -FilePath "C:\Program Files\nodejs\npm.cmd" -ArgumentList "install", "npm-check-updates", "-g" -Wait
                Write-Verbose -Message "Finished installing pm2 dependencies..."
                
                Write-Verbose -Message "Installing pm2..."
                Start-Process -FilePath "C:\Program Files\nodejs\npm.cmd" -ArgumentList "install", "pm2", "-g" -Wait
                Write-Verbose -Message "Finished installing pm2..."

                Write-Verbose -Message "Installing pm2-windows-service npm module..."
                Start-Process -FilePath "C:\Program Files\nodejs\npm.cmd" -ArgumentList "install", "pm2-windows-service", "-g" -Wait
                Write-Verbose -Message "Finished installing pm2-windows-service npm module..."

                Write-Verbose -Message "Adding npm modules to path..."
                $addPath = $env:APPDATA + "\npm"
                $regexAddPath = [regex]::Escape($addPath)
                $arrPath = $env:Path -split ';' | Where-Object {$_ -notMatch "^$regexAddPath\\?"}
                $env:Path = ($arrPath + $addPath) -join ';'
                Write-Verbose -Message "Finished adding npm modules to path..."
                
                $pm2Home = $using:PM2Home
                $env:PM2_HOME = $pm2Home
                [Environment]::SetEnvironmentVariable("PM2_HOME", $env:PM2_HOME, "Machine")

                # $exePath = $env:APPDATA + "\npm\pm2-service-install.cmd"
                # Write-Verbose -Message "Installing pm2 as a service..."
                # Start-Process -FilePath $exePath -Wait
                # Write-Verbose -Message "Finished installing pm2 as a service..."
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
            DependsOn="[xScript]GrantPM2FullControlToLocalService"
            PsDscRunAsCredential = $ScriptRunAsCreds
        }
    }
}