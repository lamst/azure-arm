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
        # Download .NET Core Hosting Bundle
        #**********************************************************
        File DownloadFolder
        {
            DestinationPath = "C:\Downloads"
            Type = "Directory"
            Ensure = "Present"
        }

        #**********************************************************
        # Install .NET Core Hosting Bundle
        #**********************************************************
        xRemoteFile DownloadDotNetCoreHostingBundle 
        {
            Uri = "https://download.visualstudio.microsoft.com/download/pr/5a059308-c27a-4223-b04d-0e815dce2cd0/10f528c237fed56192ea22283d81c409/dotnet-hosting-2.1.16-win.exe"
            DestinationPath = "C:\Downloads\dotnet-hosting-2.1.16-win.exe"
            MatchSource = $false
            DependsOn = "[File]DownloadFolder"
        }

        xPackage InstallDotNetCoreHostingBundle 
        {
            Name = "Microsoft ASP.NET Core Module"
            ProductId = ""
            Arguments = "/quiet /norestart /log C:\Downloads\dotnet-hosting-install.log"
            Path = "C:\Downloads\dotnet-hosting-2.1.16-win.exe"
            DependsOn = "[WindowsFeature]InstallWebServer", "[xRemoteFile]DownloadDotNetCoreHostingBundle"
        }

        #**********************************************************
        # Install Microsoft Build Tools 2015
        #**********************************************************
        xRemoteFile DownloadBuildTools 
        {
            Uri = "https://download.microsoft.com/download/E/E/D/EEDF18A8-4AED-4CE0-BEBE-70A83094FC5A/BuildTools_Full.exe"
            DestinationPath = "C:\Downloads\BuildTools_Full.exe"
            MatchSource = $false
            DependsOn = "[File]DownloadFolder"
        }

        xPackage InstallBuildToolds 
        {
            Name = "Microsoft Build Tools 2015"
            ProductId = ""
            Arguments = "/quiet /norestart /log C:\Downloads\build-tools-install.log"
            Path = "C:\Downloads\BuildTools_Full.exe"
            DependsOn = "[xRemoteFile]DownloadBuildTools"
        }

        #**********************************************************
        # Install .NET Framework 4.7.2
        #**********************************************************
        xRemoteFile DownloadDotNetFramework 
        {
            Uri = "https://go.microsoft.com/fwlink/?LinkID=863265"
            DestinationPath = "C:\Downloads\dotnet-framework-4.7.2.exe"
            MatchSource = $false
            DependsOn = "[File]DownloadFolder"
        }

        xPackage InstallDotNetFramework 
        {
            Name = "Microsoft .NET Framework 4.7.2"
            ProductId = ""
            Arguments = "/quiet /norestart /log C:\Downloads\dotnet-framework-install.log"
            Path = "C:\Downloads\dotnet-framework-4.7.2.exe"
            DependsOn = "[xRemoteFile]DownloadDotNetFramework"
        }
    }
}