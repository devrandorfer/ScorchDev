configuration Linux
{

    $Vars = Get-BatchAutomationVariable -Prefix LogAnalytics `
                                        -Name WorkspaceId
    $Key = (Get-AutomationPSCredential -Name $Vars.WorkspaceId).GetNetworkCredential().Password

    $AgentVersion = '1.1.1.316'
    # Import the DSC module nx
    Import-DSCResource -Module nx
    # Node name or IP
    node ubuntu
    {
        # Use the nxScript resource to create a cronjob.
        nxScript CronJob{
        GetScript = @'
#!/bin/bash
dpkg --list omsconfig | grep  1.1.1.316 && echo "agent exists" || echo "agent doesn't exist"
'@
        SetScript = @"
#!/bin/bash
wget https://raw.githubusercontent.com/Microsoft/OMS-Agent-for-Linux/master/installer/scripts/onboard_agent.sh
sudo sh ./omsagent-1.3.0-1.universal.x64.sh --upgrade -w $($Vars.WorkspaceId) -s $Key
"@
        TestScript = @"
#!/bin/bash
dpkg --list omsconfig | grep $AgentVersion && exit 0 || exit 1
"@
        }
    }
}
