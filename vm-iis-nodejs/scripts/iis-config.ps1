Configuration ConfigureWebServer
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

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
            DependsOn = "[WindowsFeature]InstallWebServer", "[xRemoteFile]DownloadDotNetFramework"
        }
    }
}