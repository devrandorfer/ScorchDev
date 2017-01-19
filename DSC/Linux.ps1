# DSC configuration CronJob
configuration CronJob
{
    # Import the DSC module nx
    Import-DSCResource -Module nx
    # Node name or IP
    node linux.localdomain
    {
        # Use the nxScript resource to create a cronjob.
        nxScript CronJob{
        GetScript = @'
#!/bin/bash
crontab -l | grep -q "powershell -c /tmp/Send-Login.ps1" && echo 'Job exists' || echo 'Job does not exist'
'@
        SetScript = @'
#!/bin/bash
(crontab -l | grep -v -F "powershell -c /tmp/Send-Login.ps1" ; echo "*/5 * * * * powershell -c /tmp/Send-Login.ps1" ) | crontab
'@
        TestScript = @'
#!/bin/bash
crontab -l | grep -q "powershell -c /tmp/Send-Login.ps1" && exit 0 || exit 1
'@
        }
    }
}
