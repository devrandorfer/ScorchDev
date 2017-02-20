configuration DomainController 
{ 
    Import-DscResource -ModuleName xDisk,
                                   xNetworking,
                                   xPendingReboot,
                                   cDisk,
                                   xPSDesiredStateConfiguration,
                                   PSDesiredStateConfiguration,
                                   cWindowscomputer,
                                   cAzureAutomation,
                                   xWindowsUpdate

    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.13.0.0

    $SourceDir = 'd:\Source'

    $zzGlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                              -Name @(
        'WorkspaceID'
    )

    $GlobalVars = Get-BatchAutomationVariable -Prefix 'Global' `
                                              -Name @(
        'DomainCredentialName',
        'DomainName'
    )


    $WorkspaceCredential = Get-AutomationPSCredential -Name $zzGlobalVars.WorkspaceID
    $WorkspaceKey = $WorkspaceCredential.GetNetworkCredential().Password

    $MMARemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkID=517476'
    $MMASetupExe = 'MMASetup-AMD64.exe'
    
    $MMACommandLineArguments = 
        '/Q /C:"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 AcceptEndUserLicenseAgreement=1 ' +
        "OPINSIGHTS_WORKSPACE_ID=$($zzGlobalVars.WorkspaceID) " +
        "OPINSIGHTS_WORKSPACE_KEY=$($WorkspaceKey)`""

    $ADMVersion = '9.0.3'
    $ADMRemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkId=698625'
    $ADMSetupExe = 'ADM-Agent-Windows.exe'
    $ADMCommandLineArguments = '/S'


    $DomainCredentail = Get-AutomationPSCredential -Name $GlobalVars.DomainCredentialName
    $RetryCount = 20
    $RetryIntervalSec = 30

    Node PDC
    {
        WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"
        }

        xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        cDiskNoRestart ADDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
        }  

        xADDomain FirstDS 
        {
            DomainName = $GlobalVars.DomainName
            DomainAdministratorCredential = $DomainCredentail
            SafemodeAdministratorPassword = $DomainCredentail
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
            DependsOn = "[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress","[cDiskNoRestart]ADDataDisk"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $GlobalVars.DomainName
            DomainUserCredential = $DomainCredentail
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn = "[xADDomain]FirstDS"
        } 

        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xWaitForADDomain]DscForestWait"
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
    Node BDC
    {
        xWaitforDisk Disk2
        {
                DiskNumber = 2
                RetryIntervalSec =$RetryIntervalSec
                RetryCount = $RetryCount
        }
        cDiskNoRestart ADDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }
        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
        }
        WindowsFeature ADDSTools
        {
            Ensure = "Present" 
            Name = "RSAT-ADDS"
        }
        xWaitForADDomain DscForestWait 
        { 
            DomainName = $GlobalVars.DomainName
            DomainUserCredential = $DomainCredentail
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec
        } 
        xADDomainController BDC 
        { 
            DomainName = $GlobalVars.DomainName
            DomainAdministratorCredential = $DomainCredentail
            SafemodeAdministratorPassword = $DomainCredentail
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
        }

        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xADDomainController]BDC"
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