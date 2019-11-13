function Start-AzPolicyEvaluation {
    Param($ResourceGroup)

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
        $response = Invoke-WebRequest -Method $method `
            -Uri $uri `
            -Headers @{ "Authorization" = "Bearer " + $token.Token } -UseBasicParsing -ErrorAction Stop
        Write-Output $response.StatusDescription
    }   
    catch {
        throw $Error[0].Exception.Message
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