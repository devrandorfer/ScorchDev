Configuration AzureAutomation
{
    Param(
    )

    # Import the required modules
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module cGit -ModuleVersion 0.1.3
    Import-DscResource -Module cWindowscomputer
    Import-DscResource -Module cAzureAutomation
    Import-DscResource -Module xDSCDomainjoin -ModuleVersion 1.1
    Import-DscResource -Module cInternetExplorerESC

    $SourceDir = 'c:\Source'

    $GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                              -Name @(
        'AutomationAccountName',
        'SubscriptionName',
        'SubscriptionAccessCredentialName',
        'SubscriptionAccessTenant'
        'ResourceGroupName',
        'WorkspaceID',
        'HybridWorkerGroup',
        'GitRepository',
        'LocalGitRepositoryRoot',
        'DomainJoinCredentialName',
        'DomainName'
    )

    $SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
    $DomainJoinCredential = Get-AutomationPSCredential -Name $GlobalVars.DomainJoinCredentialName
    
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant

    $RegistrationInfo = Get-AzureRmAutomationRegistrationInfo -ResourceGroupName $GlobalVars.ResourceGroupName `
                                                              -AutomationAccountName $GlobalVars.AutomationAccountName

    $WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
    $WorkspaceKey = $WorkspaceCredential.GetNetworkCredential().Password

    $MMARemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkID=517476'
    $MMASetupExe = 'MMASetup-AMD64.exe'
    
    $MMACommandLineArguments = 
        '/Q /C:"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 AcceptEndUserLicenseAgreement=1 ' +
        "OPINSIGHTS_WORKSPACE_ID=$($GlobalVars.WorkspaceID) " +
        "OPINSIGHTS_WORKSPACE_KEY=$($WorkspaceKey)`""

    $ADMVersion = '9.0.2'
    $ADMRemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkId=698625'
    $ADMSetupExe = 'ADM-Agent-Windows.exe'
    $ADMCommandLineArguments = '/S'

    $GITVersion = '2.8.1'
    $GITRemotSetupExeURI = "https://github.com/git-for-windows/git/releases/download/v$($GITVersion).windows.1/Git-$($GITVersion)-64-bit.exe"
    $GITSetupExe = "Git-$($GITVersion)-64-bit.exe"
    
    $GITCommandLineArguments = 
        '/VERYSILENT /NORESTART /NOCANCEL /SP- ' +
        '/COMPONENTS="icons,icons\quicklaunch,ext,ext\shellhere,ext\guihere,assoc,assoc_sh" /LOG'

    $MSOLSignInAssistantURI = 'https://download.microsoft.com/download/5/0/1/5017D39B-8E29-48C8-91A8-8D0E4968E6D4/en/msoidcli_64.msi'
    $MSOLSignInAssistantSetup = 'msoidcli_64.msi'
    $MSOLSignInAssistantCommanLineArguments = '/qn'

    
    $MSOLADURI = 'http://go.microsoft.com/fwlink/p/?linkid=236297'
    $MSOLADSetup = 'AdministrationConfig-en.msi'
    $MSOLADCommanLineArguments = '/qn'

    
    $MSOLSkypeOnlinePowershellURI = 'https://download.microsoft.com/download/2/0/5/2050B39B-4DA5-48E0-B768-583533B42C3B/SkypeOnlinePowershell.exe'
    $MSOLSkypeOnlinePowershellSetup = 'SkypeOnlinePowershell.exe'
    $MSOLSkypeOnlinePowershellCommanLineArguments = '/S'

    Node HybridRunbookWorker
    {
        File SourceFolder
        {
            DestinationPath = $($SourceDir)
            Type = 'Directory'
            Ensure = 'Present'
        }
        xRemoteFile DownloadGitSetup
        {
            Uri = $GITRemotSetupExeURI
            DestinationPath = "$($SourceDir)\$($GITSetupExe)"
            MatchSource = $False
            DependsOn = '[File]SourceFolder'
        }
        xPackage InstallGIT
        {
             Name = "Git version $($GITVersion)"
             Path = "$($SourceDir)\$($GitSetupExE)" 
             Arguments = $GITCommandLineArguments 
             Ensure = 'Present'
             InstalledCheckRegKey = 'SOFTWARE\GitForWindows'
             InstalledCheckRegValueName = 'CurrentVersion'
             InstalledCheckRegValueData = $GITVersion
             ProductID = ''
             DependsOn = "[xRemoteFile]DownloadGitSetup"
        }
        $HybridRunbookWorkerDependency = @('[xPackage]InstallGIT')

        cPathLocation GitExePath
        {
            Name = 'GitEXEPath'
            Path = @(
                'C:\Program Files\Git\cmd'
            )
            Ensure = 'Present'
            DependsOn = '[xPackage]InstallGIT'
        }
        $HybridRunbookWorkerDependency = @("[xPackage]InstallGIT")

        File LocalGitRepositoryRoot
        {
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = $GlobalVars.LocalGitRepositoryRoot
            DependsOn = '[xPackage]InstallGIT'
        }
        
        $RepositoryTable = $GlobalVars.GitRepository | ConvertFrom-JSON | ConvertFrom-PSCustomObject
        
        $PSModulePath = @()
        Foreach ($RepositoryPath in $RepositoryTable.Keys)
        {
            $RepositoryName = $RepositoryPath.Split('/')[-1]
            $Branch = $RepositoryTable.$RepositoryPath
            $PSModulePath += "$($GlobalVars.LocalGitRepositoryRoot)\$($RepositoryName)\PowerShellModules"
            cGitRepository "$RepositoryName"
            {
                Repository = $RepositoryPath
                BaseDirectory = $GlobalVars.LocalGitRepositoryRoot
                Ensure = 'Present'
                DependsOn = '[xPackage]InstallGIT'
            }
            $HybridRunbookWorkerDependency += "[cGitRepository]$($RepositoryName)"
            
            cGitRepositoryBranch "$RepositoryName-$Branch"
            {
                Repository = $RepositoryPath
                BaseDirectory = $GlobalVars.LocalGitRepositoryRoot
                Branch = $Branch
                DependsOn = '[xPackage]InstallGIT'
            }
            $HybridRunbookWorkerDependency += "[cGitRepositoryBranch]$RepositoryName-$Branch"
            
            cGitRepositoryBranchUpdate "$RepositoryName-$Branch"
            {
                Repository = $RepositoryPath
                BaseDirectory = $GlobalVars.LocalGitRepositoryRoot
                Branch = $Branch
                DependsOn = '[xPackage]InstallGIT'
            }
            $HybridRunbookWorkerDependency += "[cGitRepositoryBranchUpdate]$RepositoryName-$Branch"
        }
        
        cPSModulePathLocation GITRepositoryPowerShellModules
        {
            Name = 'GITRepositoryPowerShellModules'
            Path = $PSModulePath
            Ensure = 'Present'
            DependsOn = '[File]LocalGitRepositoryRoot'
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
        $HybridRunbookWorkerDependency += "[xPackage]InstallMicrosoftManagementAgent"
        
        xDSCDomainjoin JoinDomain
        {
            Domain = $GlobalVars.DomainName
            Credential = $DomainJoinCredential
        }
        $HybridRunbookWorkerDependency += "[xDSCDomainjoin]JoinDomain"

        cHybridRunbookWorkerRegistration HybridRegistration
        {
            RunbookWorkerGroup = $GlobalVars.HybridWorkerGroup
            AutomationAccountURL = $RegistrationInfo.Endpoint
            Key = $RegistrationInfo.PrimaryKey
            DependsOn = $HybridRunbookWorkerDependency
        }

        InternetExplorerESC DisabledInternetExplorerESC
        {
            Name = 'DisabledInternetExplorerESC'
            Enabled = $False
        }
        
        cAzureNetworkPerformanceMonitoring EnableAzureNPM
        {
            Name = 'EnableNPM'
            Ensure = 'Present'
        }

        xRemoteFile DownloadMicrosoftOnlineServicesSignInAssistant
        {
            Uri = $MSOLSignInAssistantURI
            DestinationPath = "$($SourceDir)\$($MSOLSignInAssistantSetup)"
            MatchSource = $False
        }
        xPackage InstallMicrosoftOnlineServicesSignInAssistant
        {
             Name = 'Microsoft Online Services Sign-in Assistant'
             Path = "$($SourceDir)\$($MSOLSignInAssistantSetup)" 
             Arguments = $MSOLSignInAssistantCommanLineArguments 
             Ensure = 'Present'
             ProductID = 'D8AB93B0-6FBF-44A0-971F-C0669B5AE6DD'
             DependsOn = '[xRemoteFile]DownloadMicrosoftOnlineServicesSignInAssistant'
        }

        xRemoteFile DownloadWindowsAzureActiveDirectoryModuleForWindowsPowerShell
        {
            Uri = $MSOLADURI
            DestinationPath = "$($SourceDir)\$($MSOLADSetup)"
            MatchSource = $False
        }
        xPackage InstallWindowsAzureActiveDirectoryModuleForWindowsPowerShell
        {
             Name = 'Windows Azure Active Directory Module for Windows PowerShell'
             Path = "$($SourceDir)\$($MSOLADSetup)" 
             Arguments = $MSOLADCommanLineArguments 
             Ensure = 'Present'
             ProductID = '43CC9C53-A217-4850-B5B2-8C347920E500'
             DependsOn = '[xRemoteFile]DownloadWindowsAzureActiveDirectoryModuleForWindowsPowerShell'
        }

        xRemoteFile DownloadSkypeOnlinePowershell
        {
            Uri = $MSOLSkypeOnlinePowershellURI
            DestinationPath = "$($SourceDir)\$($MSOLSkypeOnlinePowershellSetup)"
            MatchSource = $False
        }
        xPackage InstallSkypeOnlinePowershell
        {
             Name = 'Skype for Business Online, Windows PowerShell Module'
             Path = "$($SourceDir)\$($MSOLSkypeOnlinePowershellSetup)" 
             Arguments = $MSOLSkypeOnlinePowershellCommanLineArguments 
             Ensure = 'Present'
             ProductID = 'D7334D5D-0FA2-4DA9-8D8A-883F8C0BD41B'
             DependsOn = '[xRemoteFile]DownloadSkypeOnlinePowershell'
        }
    }
}
