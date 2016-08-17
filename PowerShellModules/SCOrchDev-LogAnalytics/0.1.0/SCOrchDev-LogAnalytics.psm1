#Build API signature
Function BuildSignature
{
    Param(
         $customerId,
         $sharedKey,
         $date,
         $contentLength,
         $method,
         $contentType,
         $resource
    )
    $CompletedParams = Write-StartingMessage -Stream Debug

    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash

    Write-CompletedMessage @CompletedParams -Status $authorization
    return $authorization
}

# Build & send request to POST API
Function Write-LogAnalyticsLogEntry
{
    Param(
        [Parameter(
            Mandatory=$True,
            ValueFromPipeline=$True                        
        )]
        [string]
        $WorkspaceId,

        [Parameter(
            Mandatory=$True,
            ValueFromPipeline=$True
        )]
        [string]
        $Key,

        [Parameter(
            Mandatory=$True,
            ValueFromPipeline=$True
        )]
        $Data,

        [Parameter(
            Mandatory=$True,
            ValueFromPipeline=$True
        )]
        [string]
        $LogType,

        [Parameter(
            Mandatory=$False,
            ValueFromPipeline=$True
        )]
        [string]
        $TimeStampField
    )
    $CompletedParams = Write-StartingMessage -Stream Debug

    $Data = $Data | ConvertTo-JSON -Depth ([int]::MaxValue)
    Write-Debug -message $Data
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $Data.Length
    $signature = BuildSignature -customerId $WorkspaceId `
                                -sharedKey $Key `
                                -date $rfc1123date `
                                -contentLength $contentLength `
                                -method $method `
                                -contentType $contentType `
                                -resource $resource

    $uri = "https://" + $WorkspaceId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $LogType;
        "x-ms-date" = $rfc1123date;
    }
    if($TimeStampField) { $headers.Add('time-generated-field', $TimeStampField) | Out-Null }
    $response = Invoke-WebRequest -Uri $uri `
                                  -Method $method `
                                  -ContentType $contentType `
                                  -Headers $headers `
                                  -Body $Data
    
    if ($response.StatusCode -eq 202)
    {
        Write-Debug -Message 'Accepted'
    }

    Write-CompletedMessage @CompletedParams -Status ($response | Select-Object -Property StatusCode,StatusDescription | ConvertTo-JSON -Depth 1)
}

Export-ModuleMember -Function *-* -Verbose:$False -Debug:$False