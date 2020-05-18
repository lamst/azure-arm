Configuration ConfigureWebServer
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration, PSDesiredStateConfiguration

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
        # Download PM2 Windows Service Installer
        #**********************************************************
        xRemoteFile DownloadPM2Installer
        {
            Uri = "https://github.com/jessety/pm2-installer/archive/master.zip"
            DestinationPath = "C:\Downloads\pm2-installer.zip"
            MatchSource = $false
            DependsOn = "[File]DownloadFolder"
        }

        Archive ExtractPM2Installer
        {
            Destination = "C:\Downloads\"
            Path = "C:\Downloads\pm2-installer.zip"
            Force = $true
            DependsOn = "[xRemoteFile]DownloadPM2Installer", "[xPackage]InstallNodeJS"
        }

        #**********************************************************
        # Install PM2 Service
        #**********************************************************
        xScript InstallPM2Services
        {
            SetScript =
            {
                $pm2Installer = "C:\Downloads\pm2-installer-master"

                Write-Verbose -Message "Configuring pm2 installer..."
                Start-Process -FilePath cmd.exe -ArgumentList "/c", "cd $pm2Installer && npm run configure" -Wait

                Write-Verbose -Message "Installing pm2 service..."
                Start-Process -FilePath cmd.exe -ArgumentList "/c", "cd $pm2Installer && npm run setup" -Wait
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
            DependsOn="[Archive]ExtractPM2Installer"
        }
    }
}