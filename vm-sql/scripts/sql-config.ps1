Configuration ConfigureSqlServer
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration, StorageDsc

    node localhost
    {
        LocalConfigurationManager 
        {
            ConfigurationMode  = "ApplyOnly"
            ActionAfterReboot  = 'ContinueConfiguration'
            RebootNodeIfNeeded = $true
        }
    }
}