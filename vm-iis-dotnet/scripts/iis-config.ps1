Configuration ConfigureWebServer
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    node ("localhost")
    {
        WindowsFeature InstallWebServer
        {
            Ensure = "Present"
            Name = "Web Server"
        }

        #**********************************************************
        # Download and install .NET Core Hosting Bundle
        #**********************************************************
        xRemoteFile DownloadDotNetCoreHostingBundle 
        {
            Uri = "https://download.visualstudio.microsoft.com/download/pr/5a059308-c27a-4223-b04d-0e815dce2cd0/10f528c237fed56192ea22283d81c409/dotnet-hosting-2.1.16-win.exe"
            DestinationPath = "C:\temp\dnhosting.exe"
            MatchSource = $false
        }

        xPackage InstallDotNetCoreHostingBundle 
        {
            Name = "Microsoft ASP.NET Core Module"
            ProductId = ""
            Arguments = "/quiet /norestart /log C:\temp\dnhosting_install.log"
            Path = "C:\temp\dnhosting.exe"
            DependsOn = "[WindowsFeature]InstallWebServer", "[xRemoteFile]DownloadDotNetCoreHostingBundle"
        }
    }
}