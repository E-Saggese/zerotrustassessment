﻿<#
.SYNOPSIS
    Gets the results of all the Zero Trust Assessment tests
#>

function Get-ZtTestResults {
    [CmdletBinding()]
    param ()

    $mgContext = Get-MgContext

    $tenantId = $mgContext.TenantId
    $org = GetOrganization
    $account = $mgContext.Account

    $currentVersion = ((Get-Module -Name ZeroTrustAssessment).Version | Select-Object -Last 1).ToString()
    $latestVersion = GetModuleLatestVersion

    $ztTestResults = [PSCustomObject]@{
        ExecutedAt     = GetFormattedDate(Get-Date)
        TenantId       = $tenantId
        TenantName     = $org.TenantName
        Domain         = $org.Domain
        Account        = $account
        CurrentVersion = $currentVersion
        LatestVersion  = $latestVersion
        Tests          = $__ZtSession.TestResultDetail.values
    }

    return $ztTestResults
}

function GetModuleLatestVersion() {
    if (Get-Command 'Find-Module' -ErrorAction SilentlyContinue) {
        return (Find-Module -Name ZeroTrustAssessment).Version
    }

    return 'Unknown'
}

function GetFormattedDate($date) {
    if(!$IsCoreCLR) { # Prevent 5.1 date format to json issue
        return $date.ToString("o")
    }
    else {
        return $date
    }
}

function GetOrganization() {
    $org = Invoke-ZtGraphRequest -RelativeUri 'organization'
    $defaultDomain = $org.verifiedDomains | Where-Object { $_.isDefault } | Select-Object -First 1
    return [PSCustomObject]@{
        TenantName = $org.displayName
        Domain     = $defaultDomain.name
    }
}
