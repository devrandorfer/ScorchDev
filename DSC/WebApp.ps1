Configuration WebApp
{
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module cWindowscomputer
    Import-DscResource -Module cAzureAutomation
    Import-DscResource -Module xPendingReboot
    Import-DscResource -Module xDSCDomainjoin -ModuleVersion 1.1
    Import-DscResource -Module xWebAdministration
    Import-DscResource -Module cNetworkAdapter
    Import-DscResource -Module cDisk
    Import-DscResource -Module xDisk
    Import-DscResource -Module xWindowsUpdate

    $SourceDir = 'D:\Source'
    $GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                              -Name @(
        'WorkspaceID',
        'DomainJoinCredentialName',
        'DomainName'
    )

    $DomainJoinCredential = Get-AutomationPSCredential -Name $GlobalVars.DomainJoinCredentialName
    
    $WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
    $WorkspaceKey = $WorkspaceCredential.GetNetworkCredential().Password

    $MMARemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkID=517476'
    $MMASetupExe = 'MMASetup-AMD64.exe'
    
    $MMACommandLineArguments = 
        '/Q /C:"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 AcceptEndUserLicenseAgreement=1 ' +
        "OPINSIGHTS_WORKSPACE_ID=$($GlobalVars.WorkspaceID) " +
        "OPINSIGHTS_WORKSPACE_KEY=$($WorkspaceKey)`""

    $ADMVersion = '9.0.3'
    $ADMRemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkId=698625'
    $ADMSetupExe = 'ADM-Agent-Windows.exe'
    $ADMCommandLineArguments = '/S'

    $RetryCount = 20
    $RetryIntervalSec = 30

    # Tanium DL information
    $TaniumClientDownloadCredential = Get-AutomationPSCredential -Name 'scotaniumsas'
    $TaniumClientDownloadURI = "https://scotanium.blob.core.windows.net/files/10.0.1.4.17472.6.0.314.1540.0..exe$($TaniumClientDownloadCredential.GetNetworkCredential().password)"
    $TaniumClientExe = 'SetupClient.exe'

    Node FrontEnd
    {   
        xWaitforDisk DataDisk
        {
                DiskNumber = 2
                RetryIntervalSec =$RetryIntervalSec
                RetryCount = $RetryCount
        }
        cDiskNoRestart DataDisk
        {
            DiskNumber = 2
            DriveLetter = 'F'
        }
        File SourceFolder
        {
            DestinationPath = $($SourceDir)
            Type = 'Directory'
            Ensure = 'Present'
        }
        xRemoteFile DownloadMicrosoftManagementAgent
        {
            Uri = $MMARemotSetupExeURI
            DestinationPath = "$($SourceDir)\$($MMASetupExe)"
            MatchSource = $False
        }
        xPackage InstallMicrosoftManagementAgent
        {
             Name = "Microsoft Monitoring Agent"
             Path = "$($SourceDir)\$($MMASetupExE)" 
             Arguments = $MMACommandLineArguments 
             Ensure = 'Present'
             InstalledCheckRegKey = 'SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup'
             InstalledCheckRegValueName = 'Product'
             InstalledCheckRegValueData = 'Microsoft Monitoring Agent'
             ProductID = ''
             DependsOn = "[xRemoteFile]DownloadMicrosoftManagementAgent"
        }
        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xPackage]InstallMicrosoftManagementAgent"
        }
        xRemoteFile DownloadAppDependencyMonitor
        {
            Uri = $ADMRemotSetupExeURI
            DestinationPath = "$($SourceDir)\$($ADMSetupExe)"
            MatchSource = $False
        }
        xPackage InstallAppDependencyMonitor
        {
             Name = "Application Dependency Monitor"
             Path = "$($SourceDir)\$($ADMSetupExE)" 
             Arguments = $ADMCommandLineArguments 
             Ensure = 'Present'
             InstalledCheckRegKey = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\DependencyAgent'
             InstalledCheckRegValueName = 'DisplayVersion'
             InstalledCheckRegValueData = $ADMVersion
             ProductID = ''
             DependsOn = "[xRemoteFile]DownloadMicrosoftManagementAgent"
        }
        xPendingReboot Reboot2
        { 
            Name = "RebootServer2"
            DependsOn = "[xPackage]InstallAppDependencyMonitor"
        }
        xDSCDomainjoin JoinDomain
        {
            Domain = $GlobalVars.DomainName
            Credential = $DomainJoinCredential
        }
        # Install the IIS role
        WindowsFeature IIS
        {
            Ensure          = 'Present'
            Name            = 'Web-Server'
        }

        WindowsFeature INETMGR
        {
            Ensure          = 'Present'
            Name            = 'Web-Mgmt-Console'
        }

        # Install the ASP .NET 4.5 role
        WindowsFeature AspNet45
        {
            Ensure          = 'Present'
            Name            = 'Web-Asp-Net45'
        }

        xIisLogging Logging
        {
            LogPath = 'F:\IISLogFiles'
            Logflags = @('Date','Time','ClientIP','UserName','ServerIP')
            LoglocalTimeRollover = $True
            LogPeriod = 'Hourly'
            LogFormat = 'W3C'
            DependsOn = '[WindowsFeature]IIS'
        }

        # Setup the default website
        xWebsite DefaultWebSite 
        {
            Ensure          = 'Present'
            Name            = 'Default Web Site'
            PhysicalPath    = 'C:\inetpub\wwwroot'
            State           = 'Stopped'
            DependsOn       = '[WindowsFeature]IIS'
        }
        
        xWebAppPool SampleAppPool
        {
            Name                           = 'SampleAppPool'
            Ensure                         = 'Present'
            State                          = 'Started'
        }
        # Download the default site content
        xRemoteFile SiteContentZip
        {
            Uri = 'https://msdnshared.blob.core.windows.net/media/MSDNBlogsFS/prod.evol.blogs.msdn.com/CommunityServer.Components.PostAttachments/00/07/43/14/54/BuggyBits.zip'
            DestinationPath = "$($SourceDir)\BuggyBits.zip"
            MatchSource = $False
            DependsOn = '[xWebsite]DefaultWebSite'
        }

        # Setup the default site content
        Archive UnpackSiteContent
        {
            Path = "$($SourceDir)\BuggyBits.zip"
            Destination = 'F:\inetpub\wwwroot'
            Ensure = 'Present'
            DependsOn = '[xRemoteFile]SiteContentZip'
        }
        
        xWebsite BuggyBits
        {
            Ensure          = 'Present'
            Name            = 'BuggyBits'
            State           = 'Started'
            PhysicalPath    = 'F:\inetpub\wwwroot\BuggyBits'
            ApplicationPool = 'SampleAppPool'
            DependsOn       = @(
                '[Archive]UnpackSiteContent'
                '[xWebAppPool]SampleAppPool'
            )
        }
        
        cAzureNetworkPerformanceMonitoring EnableAzureNPM
        {
            Name = 'EnableNPM'
            Ensure = 'Present'
        }
       
        xRemoteFile PythonDownload
        {
            Uri = 'https://www.python.org/ftp/python/2.7.12/python-2.7.12.msi'
            DestinationPath = "$($SourceDir)\python-2.7.12.msi"
            MatchSource = $False
        }
        xPackage InstallPython27
        {
             Name = "Python 2.7.12"
             Path = "$($SourceDir)\python-2.7.12.msi" 
             Arguments = '/qn ALLUSERS=1' 
             Ensure = 'Present'
             ProductID = '9DA28CE5-0AA5-429E-86D8-686ED898C665'
             DependsOn = "[xRemoteFile]PythonDownload"
        }

        # Download the default site content
        xRemoteFile NodeJS
        {
            Uri = 'https://nodejs.org/dist/v4.5.0/node-v4.5.0-x64.msi'
            DestinationPath = "$($SourceDir)\node-v4.5.0-x64.msi"
            MatchSource = $False
        }
        xPackage InstallNodeJS
        {
             Name = "Node.js"
             Path = "$($SourceDir)\node-v4.5.0-x64.msi" 
             Arguments = '/qn' 
             Ensure = 'Present'
             ProductID = 'B5FEC613-8EBC-43C3-A232-693D96E07CCF'
             DependsOn = "[xRemoteFile]NodeJS"
        }

        xRemoteFile Download-IIS-URL-ReWrite
        {
            Uri = 'http://go.microsoft.com/fwlink/?LinkID=615137'
            DestinationPath = "$($SourceDir)\rewrite_amd64.msi"
            MatchSource = $False
        }

        xPackage Install-IIS-URL-ReWrite
        {
             Name = 'IIS URL Rewrite Module 2'
             Path = "$($SourceDir)\rewrite_amd64.msi" 
             Arguments = '/qn' 
             Ensure = 'Present'
             ProductID = '08F0318A-D113-4CF0-993E-50F191D397AD'
             DependsOn = "[xRemoteFile]Download-IIS-URL-ReWrite"
        }

        xRemoteFile iisnode-core-download
        {
            Uri = 'https://github.com/tjanczuk/iisnode/releases/download/v0.2.21/iisnode-core-v0.2.21-x64.msi'
            DestinationPath = "$($SourceDir)\iisnode-core-v0.2.21-x64.msi"
            MatchSource = $False
            DependsOn = '[xPackage]Install-IIS-URL-ReWrite'
        }

        xPackage Install-iisnode-core-install
        {
             Name = 'iisnode for iis 7.x (x64) core'
             Path = "$($SourceDir)\iisnode-core-v0.2.21-x64.msi" 
             Arguments = '/qn' 
             Ensure = 'Present'
             ProductID = '93ED58D2-1180-40C2-8E96-B90D57AC3A11'
             DependsOn = "[xRemoteFile]iisnode-core-download"
        }
        xWindowsUpdateAgent MuSecurityImportant
        {
            IsSingleInstance = 'Yes'
            UpdateNow        = $true
            Category         = @('Security','Important')
            Source           = 'MicrosoftUpdate'
            Notifications    = 'Disabled'
        }
        xRemoteFile DownloadTaniumAgent
        {
            Uri = $TaniumClientDownloadURI
            DestinationPath = "$($SourceDir)\$($TaniumClientExe)"
            MatchSource = $False
        }
        xRemoteFile DownloadTaniumPub
        {
            Uri = $TaniumClientDownloadURI
            DestinationPath = "$($SourceDir)\$($TaniumClientExe)"
            MatchSource = $False
        }
        xPackage InstallTaniumClient
        {
             Name = "Tanium Client"
             Path = "$($SourceDir)\$($TaniumClientExe)" 
             Ensure = 'Present'
             InstalledCheckRegKey = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Tanium Client'
             InstalledCheckRegValueName = 'DisplayVersion'
             InstalledCheckRegValueData = '6.0.314.1540'
             ProductID = ''
             DependsOn = "[xRemoteFile]DownloadTaniumAgent"
        }
    }
    Node SQL
    {
        File SourceFolder
        {
            DestinationPath = $($SourceDir)
            Type = 'Directory'
            Ensure = 'Present'
        }
        xRemoteFile DownloadMicrosoftManagementAgent
        {
            Uri = $MMARemotSetupExeURI
            DestinationPath = "$($SourceDir)\$($MMASetupExe)"
            MatchSource = $False
        }
        xPackage InstallMicrosoftManagementAgent
        {
             Name = "Microsoft Monitoring Agent"
             Path = "$($SourceDir)\$($MMASetupExE)" 
             Arguments = $MMACommandLineArguments 
             Ensure = 'Present'
             InstalledCheckRegKey = 'SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup'
             InstalledCheckRegValueName = 'Product'
             InstalledCheckRegValueData = 'Microsoft Monitoring Agent'
             ProductID = ''
             DependsOn = "[xRemoteFile]DownloadMicrosoftManagementAgent"
        }
        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xPackage]InstallMicrosoftManagementAgent"
        }
        xRemoteFile DownloadAppDependencyMonitor
        {
            Uri = $ADMRemotSetupExeURI
            DestinationPath = "$($SourceDir)\$($ADMSetupExe)"
            MatchSource = $False
        }
        xPackage InstallAppDependencyMonitor
        {
             Name = "Application Dependency Monitor"
             Path = "$($SourceDir)\$($ADMSetupExE)" 
             Arguments = $ADMCommandLineArguments 
             Ensure = 'Present'
             InstalledCheckRegKey = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\DependencyAgent'
             InstalledCheckRegValueName = 'DisplayVersion'
             InstalledCheckRegValueData = $ADMVersion
             ProductID = ''
             DependsOn = "[xRemoteFile]DownloadMicrosoftManagementAgent"
        }
        xPendingReboot Reboot2
        { 
            Name = "RebootServer2"
            DependsOn = "[xPackage]InstallAppDependencyMonitor"
        }
        xDSCDomainjoin JoinDomain
        {
            Domain = $GlobalVars.DomainName
            Credential = $DomainJoinCredential
        }
        cAzureNetworkPerformanceMonitoring EnableAzureNPM
        {
            Name = 'EnableNPM'
            Ensure = 'Present'
        }
        xWindowsUpdateAgent MuSecurityImportant
        {
            IsSingleInstance = 'Yes'
            UpdateNow        = $true
            Category         = @('Security','Important')
            Source           = 'MicrosoftUpdate'
            Notifications    = 'Disabled'
        }
    }
}
