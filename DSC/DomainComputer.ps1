Configuration DomainComputer
{
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module cWindowscomputer
    Import-DscResource -Module cAzureAutomation
    Import-DscResource -Module xPendingReboot
    Import-DscResource -Module xDSCDomainjoin -ModuleVersion 1.1
    Import-DscResource -Module xWebAdministration
    Import-DscResource -Module cNetworkAdapter

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

    $ADMVersion = '8.2.4'
    $ADMRemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkId=698625'
    $ADMSetupExe = 'ADM-Agent-Windows.exe'
    $ADMCommandLineArguments = '/S'

    $MicrosoftAzureSiteRecoveryUnifiedSetupURI = 'http://aka.ms/unifiedinstaller'
    $ASRSetupEXE = 'MicrosoftAzureSiteRecoveryUnifiedSetup.exe'

    Node MemberServerDev
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
             InstalledCheckRegKey = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\BlueStripeCollector'
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
        NetworkAdapterComponent ms_rspndr
        {
            ComponentId = 'ms_rspndr'
            Enabled = $False
        }
        NetworkAdapterComponent ms_lltdio
        {
            ComponentId = 'ms_lltdio'
            Enabled = $False
        }
        cAzureNetworkPerformanceMonitoring EnableAzureNPM
        {
            Name = 'EnableNPM'
            Ensure = 'Present'
        }
    }
    Node MemberServerQA
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
             InstalledCheckRegKey = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\BlueStripeCollector'
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
    }
    Node MemberServerProd
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
             InstalledCheckRegKey = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\BlueStripeCollector'
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
    }
    Node WebServerProd
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
             InstalledCheckRegKey = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\BlueStripeCollector'
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

        # Install the ASP .NET 4.5 role
        WindowsFeature AspNet45
        {
            Ensure          = 'Present'
            Name            = 'Web-Asp-Net45'
        }

        # Stop the default website
        xWebsite DefaultSite 
        {
            Ensure          = 'Present'
            Name            = 'Default Web Site'
            State           = 'Started'
            PhysicalPath    = 'C:\inetpub\wwwroot'
            DependsOn       = '[WindowsFeature]IIS'
        }
        cAzureNetworkPerformanceMonitoring EnableAzureNPM
        {
            Name = 'EnableNPM'
            Ensure = 'Present'
        }
    }
    Node ASR_ManagementServer
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
             InstalledCheckRegKey = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\BlueStripeCollector'
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
        xRemoteFile DownloadAzureSiteRecoveryUnifiedSetup
        {
            Uri = $MicrosoftAzureSiteRecoveryUnifiedSetupURI
            DestinationPath = "$($SourceDir)\$($ASRSetupEXE)"
            MatchSource = $False
        }
        cAzureNetworkPerformanceMonitoring EnableAzureNPM
        {
            Name = 'EnableNPM'
            Ensure = 'Present'
        }
    }
}
