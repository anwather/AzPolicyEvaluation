function Start-AzPolicyEvaluation {
    [CmdletBinding()]
    Param($ResourceGroup, [switch]$Wait)

    try {
        $token = Get-AzToken
    }
    catch {
        throw "You must be logged in to Azure - Use Connect-AzAccount to connect."
    }

    if ($null -eq $ResourceGroup) {
        $uri = "https://management.azure.com/subscriptions/$($token.SubscriptionId)/providers/Microsoft.PolicyInsights/policyStates/latest/triggerEvaluation?api-version=2018-07-01-preview"
    }
    else {
        $uri = "https://management.azure.com/subscriptions/$($token.SubscriptionId)/resourceGroups/$ResourceGroup/providers/Microsoft.PolicyInsights/policyStates/latest/triggerEvaluation?api-version=2018-07-01-preview"
    }

    $method = "POST"

    try {
        Write-Verbose -Message "Sending Web Request"
        $response = Invoke-WebRequest -Method $method `
            -Uri $uri `
            -Headers @{ "Authorization" = "Bearer " + $token.Token } -UseBasicParsing -ErrorAction Stop
        Write-Output $response.StatusDescription
        if (!($PSBoundParameters.ContainsKey('Wait'))) {
            $obj = [PSCustomObject]@{
                StatusCode        = $response.StatusCode
                StatusDescription = $response.StatusDescription
            }
            return $obj
        }
    }   
    catch {
        throw $Error[0].Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('Wait')) {
        Write-Verbose "Waiting for policy to finish evaluating"
        $locationURI = "$($response.Headers.Location)"
        do {
            $response = Invoke-WebRequest -Uri $locationURI `
                -Headers @{ "Authorization" = "Bearer " + $token.Token } -UseBasicParsing -ErrorAction Stop
            Write-Verbose "x-ms-ratelimit-remaining-subscription-policy-insights-requests: $($response.Headers.'x-ms-ratelimit-remaining-subscription-policy-insights-requests')"
            Write-Verbose "$($response.StatusCode) - $($response.StatusDescription)"
            Start-Sleep -Seconds 30

        }
        while (($response.StatusCode -eq 202) -and ($response.StatusDescription -eq 'Accepted'))

        $obj = [PSCustomObject]@{
            StatusCode        = $response.StatusCode
            StatusDescription = $response.StatusDescription
        }
        return $obj
        
    }
}

function Get-AzToken {
    $subDetails = Get-AzContext | Select-Object Tenant, Subscription
    $tokenCache = Get-AzContext | Select-Object -ExpandProperty TokenCache
    $cachedTokens = $tokenCache.ReadItems() `
    | Where-Object { $_.TenantId -eq $subDetails.Tenant } `
    | Sort-Object -Property ExpiresOn -Descending
    $accessToken = $cachedTokens[0].AccessToken
    $obj = [PScustomObject]@{
        SubscriptionID = $subDetails.Subscription
        TenantID       = $subDetails.Tenant
        Token          = $accessToken
    }
    return $obj
}