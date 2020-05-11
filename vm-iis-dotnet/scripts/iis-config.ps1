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
        # Install .NET Framework 4.6.2
        #**********************************************************
        xRemoteFile DownloadDotNetFramework 
        {
            Uri = "http://go.microsoft.com/fwlink/?linkid=780600"
            DestinationPath = "C:\Downloads\dotnet-fx-4.6.2-x86.exe"
            MatchSource = $false
            DependsOn = "[File]DownloadFolder"
        }

        xPackage InstallDotNetFramework 
        {
            Name = "Microsoft .NET Framework"
            ProductId = ""
            Arguments = "/q /norestart /log C:\Downloads\dotnet-fx-install.log"
            Path = "C:\Downloads\dotnet-fx-4.6.2-x86.exe"
            DependsOn = "[WindowsFeature]InstallWebServer", "[xRemoteFile]DownloadDotNetFramework"
        }
    }
}