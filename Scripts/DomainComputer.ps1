Configuration DomainComputer
{
    # Import the required modules
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module cWindowscomputer
    Import-DscResource -Module cAzureAutomation
    Import-DscResource -Module xPendingReboot
    Import-DscResource -Module xDSCDomainjoin -ModuleVersion 1.1

    $SourceDir = 'd:\Source'
    $GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                              -Name @(
        'DomainJoinCredentialName',
        'DefaultDomainName'
    )

    $DomainJoinCredential = Get-AutomationPSCredential -Name $GlobalVars.DomainJoinCredentialName

    $MMARemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkID=517476'
    $MMASetupExe = 'MMASetup-AMD64.exe'

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
        xDSCDomainjoin JoinDomain
        {
            Domain = $GlobalVars.DefaultDomainName
            Credential = $DomainJoinCredential
        }
        File DownloadAutomationBuildInstalls
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            Recurse = $true # Ensure presence of subdirectories, too
            SourcePath = "\\servername\d$\SCORCH_Data\CorpServerAutomatedBuilds\Installs\McAfee5.2"
            DestinationPath = "$($SourceDir)\McAfee"
            Credential = $DomainJoinCredential
            DependsOn = "[xDSCDomainjoin]JoinDomain"
        }
        xPackage InstallMcAfee
        {
             Name = "McAfee Agent and Client"
             Path = "$($SourceDir)\McAfee\NewFramePkg502.exe" 
             Arguments = '/Install=Agent /Silent'
             Ensure = 'Present'
             InstalledCheckRegKey = 'SOFTWARE\Agent\Applications\EPOAGENT3000'
             InstalledCheckRegValueName = 'ProductName'
             InstalledCheckRegValueData = 'McAfee Agent'
             ProductID = ''
             DependsOn = "[File]DownloadAutomationBuildInstalls"
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
        xDSCDomainjoin JoinDomain
        {
            Domain = $GlobalVars.DefaultDomainName
            Credential = $DomainJoinCredential
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
        xDSCDomainjoin JoinDomain
        {
            Domain = $GlobalVars.DefaultDomainName
            Credential = $DomainJoinCredential
        }
    }
}
