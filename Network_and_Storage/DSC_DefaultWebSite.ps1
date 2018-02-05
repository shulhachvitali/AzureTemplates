configuration xWebsite_SetDefault 
{ 
    param 
    ( 
        # Target nodes to apply the configuration 
        $MachineName
    ) 
    # Import the module that defines custom resources
    Import-DscResource -ModuleName PSDesiredStateConfiguration 
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName xNetworking
    Node $MachineName
    { 
        # Install the IIS role 
        WindowsFeature IIS 
        { 
            Ensure          = "Present" 
            Name            = "Web-Server" 
        } 
        # Stop the default website 
        xWebsite DefaultSite  
        { 
            Ensure          = "Present" 
            Name            = "Default Web Site" 
            State           = "Started" 
            PhysicalPath    = "C:\inetpub\wwwroot" 
            BindingInfo     = MSFT_xWebBindingInformation 
                             { 
                               Protocol              = "HTTP" 
                               Port                  = 80
                             } 
            DependsOn       = "[WindowsFeature]IIS" 
        } 
        xFirewall Firewall
        {
            Name = 'allow80'
            DisplayName = 'allow 80'
            Group = 'IIS Firewall Rule Group'
            Ensure = 'Present'
            Enabled = 'True'
            Profile = ('Domain', 'Private', 'Public')
            Direction = 'InBound'
            LocalPort = ('80')
            Protocol = 'TCP'
            Description = 'Firewall Rule for IIS port 80'
        }
    } 
}