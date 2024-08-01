﻿function Export-GraphEntity {
    [CmdletBinding()]
    param (
        # The entity to export. e.g. /beta/servicePrincipals
        [string]
        [Parameter(Mandatory = $true)]
        $EntityUri,

        # Parameters to include. e.g. $expand=appRoleAssignments&$top=999
        [string]
        [Parameter(Mandatory = $false)]
        $QueryString,

        # The folder for the entity. e.g. ServicePrincipals
        [string]
        [Parameter(Mandatory = $true)]
        $EntityName,

        # The name to show in the progress bar. E.g. Service Principals
        [string]
        [Parameter(Mandatory = $true)]
        $ProgressActivity,

        # The additional properties/relations to be queried for each object. e.g. oauth2PermissionGrants
        [string[]]
        [Parameter(Mandatory = $false)]
        $RelatedPropertyNames,

        # The folder to output the report to.
        [string]
        [Parameter(Mandatory = $true)]
        $ExportPath
    )
    if ((Get-ZtConfig -ExportPath $ExportPath -Property $EntityName)) {
        Write-Verbose "Skipping $EntityName since it was downloaded previously"
        return
    }

    $activity = "Exporting $ProgressActivity"
    Write-ZtProgress $activity
    $totalCount = Get-ZtGraphObjectCount $EntityUri
    $pageIndex = 0
    $currentCount = 0

    $folderPath = Join-Path $ExportPath $EntityName
    Clear-ZtFolder $folderPath

    $uri = $EntityUri + '?' + $QueryString

    do {
        $results = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType HashTable
        $currentCount = ExportPage $pageIndex $folderPath $results $RelatedPropertyNames $EntityName $EntityUri $currentCount $totalCount $ProgressActivity

        $uri = Get-ObjectProperty $results '@odata.nextLink'
        $pageIndex++
    }while ($uri)

    Set-ZtConfig -ExportPath $ExportPath -Property $EntityName -Value $true
}

function ExportPage($pageIndex, $path, $results, $relatedPropertyNames, $entityName, $entityUri, $currentCount, $totalCount, $progressActivity) {
    Write-Verbose "Exporting $entityName page $pageIndex"

    if ($relatedPropertyNames) {
        foreach ($result in $results.value) {
            $currentCount++
            $name = Get-ObjectProperty $result 'displayName'
            Write-ZtProgress "Exporting $progressActivity" -Status "$currentCount of $totalCount : $name"
            foreach ($propertyName in $relatedPropertyNames) {
                Add-GraphProperty $result $propertyName $entityName $entityUri
            }
        }
    }
    else {
        $currentCount += $results.value.Count
        Write-ZtProgress "Exporting $progressActivity" -Status "$currentCount of $totalCount"
    }

    $filePath = Join-Path $path "$entityName-$pageIndex.json"
    $results | ConvertTo-Json -Depth 100 | Out-File -FilePath $filePath -Force
    return $currentCount
}

function Add-GraphProperty($result, $propertyName, $entityName, $entityUri) {
    $id = Get-ObjectProperty $result 'id'
    Write-Verbose "Adding $propertyName to $entityName $id"
    $propertyResults = Invoke-MgGraphRequest -Uri "$entityUri/$id/$propertyName" -OutputType HashTable
    $result[$propertyName] = Get-ObjectProperty $propertyResults 'value'
}
