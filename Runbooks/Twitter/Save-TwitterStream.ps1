<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-TwitterStream

$GlobalVars = Get-BatchAutomationVariable -Prefix 'altGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName'

$OMSVars = Get-BatchAutomationVariable -Prefix 'altOMS' `
                                       -Name 'WorkspaceName',
                                             'WorkspaceId',
                                             'ResourceGroupName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$OMSCredential = Get-AutomationPSCredential -Name $OMSVars.WorkspaceId
Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName
    
    $LastUpdateTime = Get-AutomationVariable -Name 'altOMS-LastUpdateTime'
    While($True)
    {
        Try
        {
        
            $SearchResult = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $OMSVars.ResourceGroupName `
                                                                        -WorkspaceName $OMSVars.WorkspaceName `
                                                                        -Query 'Type=TweetStream_CL (TrackingTerm_s=msignite)' `
                                                                        -Start (get-date).AddMinutes(-10) -End (get-date) -Top 5000
            $SearchResult.Value.Count
            $LastUpdateTime = Get-Date
            Set-AutomationVariable -Name 'altOMS-LastUpdateTime' -Value $LastUpdateTime
            $HashtagHT = @{}
            $TopicsHT = @{}
            $TrackingTermHT = @{}
            Foreach($Result in $SearchResult.Value)
            {
                $_Result = $Result | ConvertFrom-JSON

                if($_Result.sentimentScore_d -lt .33) { $sentiment = 'Negative' }
                elseif ($_Result.sentimentScore_d -ge .33 -and $_Result.sentimentScore_d -lt .66) { $sentiment = 'Neutral' }
                else { $sentiment = 'Positive' }

                if(($_Result | gm) | ? {$_.Name -eq 'Hashtags_s'})
                {
                    Foreach($HashTag in $_Result.Hashtags_s.Split(','))
                    {
                        if($HashtagHT.ContainsKey($HashTag))
                        {
                             $HashtagHT."$($HashTag)".$sentiment += 1
                             $HashtagHT."$($HashTag)".Count += 1
                             $HashtagHT."$($HashTag)".Total += $_Result.sentimentScore_d
                             $HashtagHT."$($HashTag)".Average = [double]($HashtagHT."$($HashTag)".Total / $HashtagHT."$($HashTag)".Count)
                        }
                        else
                        {
                            $HashtagHT."$($HashTag)" = @{
                                'Positive' = 0
                                'Neutral' = 0
                                'Negative' = 0
                                'Count' = 1
                                'Total' = $_Result.sentimentScore_d
                                'Average' = $_Result.sentimentScore_d
                            }

                            $HashtagHT."$($HashTag)".$sentiment = 1
                        }
                    }
                }
                if(($_Result | gm) | ? {$_.Name -eq 'keyPhrases_s'})
                {
                    Foreach($Topic in ($_Result.keyPhrases_s | ConvertFrom-Json))
                    {
                        if($TopicsHT.ContainsKey($Topic))
                        {
                             $TopicsHT."$($Topic)".$sentiment += 1
                             $TopicsHT."$($Topic)".Count += 1
                             $TopicsHT."$($Topic)".Total += $_Result.sentimentScore_d
                             $TopicsHT."$($Topic)".Average = [double]($TopicsHT."$($Topic)".Total / $TopicsHT."$($Topic)".Count)
                        }
                        else
                        {
                            $TopicsHT."$($Topic)" = @{
                                'Positive' = 0
                                'Neutral' = 0
                                'Negative' = 0
                                'Count' = 1
                                'Total' = $_Result.sentimentScore_d
                                'Average' = $_Result.sentimentScore_d
                            }

                            $TopicsHT."$($Topic)".$sentiment = 1
                        }
                    }
                }

                if($TrackingTermHT.ContainsKey($_Result.TrackingTerm_s))
                {
                        $TrackingTermHT."$($_Result.TrackingTerm_s)".$sentiment += 1
                        $TrackingTermHT."$($_Result.TrackingTerm_s)".Count += 1
                        $TrackingTermHT."$($_Result.TrackingTerm_s)".Total += $_Result.sentimentScore_d
                        $TrackingTermHT."$($_Result.TrackingTerm_s)".Average = [double]($TrackingTermHT."$($_Result.TrackingTerm_s)".Total / $TrackingTermHT."$($_Result.TrackingTerm_s)".Count)
                }
                else
                {
                    $TrackingTermHT."$($_Result.TrackingTerm_s)" = @{
                        'Positive' = 0
                        'Neutral' = 0
                        'Negative' = 0
                        'Count' = 1
                        'Total' = $_Result.sentimentScore_d
                        'Average' = $_Result.sentimentScore_d
                    }

                    $TrackingTermHT."$($_Result.TrackingTerm_s)".$sentiment = 1
                }
            }

            $TopicsArray = @()
            $HashtagsArray = @()
            $TrackingTermArray = @()
            foreach($Topic in $TopicsHT.keys)
            {
                $_Topic = $TopicsHT.$Topic
                $_Topic.Add('Topic', $Topic) | Out-Null
                $TopicsArray += $_Topic
            }
            foreach($HashTag in $HashtagHT.keys)
            {
                $_HashTag = $HashtagHT.$HashTag
                $_HashTag.Add('HashTag', $Hashtag) | Out-Null
                $HashtagsArray += $_HashTag
            }
            foreach($TrackingTerm in $TrackingTermHT.keys)
            {
                $_TrackingTerm = $TrackingTermHT.$TrackingTerm
                $_TrackingTerm.Add('TrackingTerm', $TrackingTerm) | Out-Null
                $TrackingTermArray += $_TrackingTerm
            }

            Write-LogAnalyticsLogEntry -WorkspaceId $OMSVars.WorkspaceId -Key $OMSCredential.GetNetworkCredential().Password -Data $TopicsArray -LogType 'TwitterTopics_CL'
            Write-LogAnalyticsLogEntry -WorkspaceId $OMSVars.WorkspaceId -Key $OMSCredential.GetNetworkCredential().Password -Data $HashtagsArray -LogType 'TwitterHashtags_CL'
            Write-LogAnalyticsLogEntry -WorkspaceId $OMSVars.WorkspaceId -Key $OMSCredential.GetNetworkCredential().Password -Data $TrackingTermArray -LogType 'TwitterTrackingTerm_CL'
        }
        Catch{
        }
    }
}
Catch
{
    $Exception = $_
    $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
    Switch ($ExceptionInfo.FullyQualifiedErrorId)
    {
        Default
        {
            Write-Exception $Exception -Stream Warning
        }
    }
}

Write-CompletedMessage @CompletedParameters
