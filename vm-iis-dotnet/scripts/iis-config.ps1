Configuration ConfigureWebServer
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    node localhost
    {
        WindowsFeature InstallWebServer
        {
            Ensure = "Present"
            Name = "Web Server"
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
    }
}