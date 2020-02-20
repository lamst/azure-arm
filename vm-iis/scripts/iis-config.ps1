Configuration ConfigureWebServer
{
    node localhost
    {
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
    }
}