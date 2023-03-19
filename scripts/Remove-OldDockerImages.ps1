﻿Param(
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyname=$true)]
    [string] $cleanAllImages = 'False',
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyname=$true)]
    [string] $keepDays = 40

)

Write-Host "Removing unused Docker Images"
$images = docker image list --format "table {{.Repository}},{{.Tag}},{{.ID}},{{.Size}},{{.CreatedAt}}"
$dockerImages = @()
$imagesToRemove = @()
$dateTimeFormat = 'yyyy-MM-dd HH:mm:ss'
$images[1..$images.length] | % {
    $fields = $_.Split(",")
    $dockerImage = New-Object -TypeName PSObject
    $dockerImage | Add-Member -MemberType NoteProperty -Name Repository -Value $fields[0]
    $dockerImage | Add-Member -MemberType NoteProperty -Name ID -Value $fields[2]
    $dockerImage | Add-Member -MemberType NoteProperty -Name Size -Value $fields[3]
    $dockerImage | Add-Member -MemberType NoteProperty -Name CreatedAt -Value ([DateTime]::ParseExact($fields[4].Substring(0, $dateTimeFormat.Length), $dateTimeFormat, $null))
    $dockerImages += $dockerImage
}

foreach ($dockerImage in ($dockerImages | Where-Object -Property Repository -eq "<none>")) {
    Write-Host "Removing Docker Image $($_.ID)"
    try { docker image rm $($dockerImage.ID) }
    catch { Write-Host "Unable to remove Docker Image $($dockerImage.ID)" }
}    

if ($cleanAllImages -ieq "true") {
    Write-Host "Removing old Docker Images"
    $images = docker image list --format "table {{.Repository}},{{.Tag}},{{.ID}},{{.Size}},{{.CreatedAt}}"
    $dockerImages = @()
    $imagesToRemove = @()
    $dateTimeFormat = 'yyyy-MM-dd HH:mm:ss'
    $images[1..$images.length] | % {
        $fields = $_.Split(",")
        $dockerImage = New-Object -TypeName PSObject
        $dockerImage | Add-Member -MemberType NoteProperty -Name Repository -Value $fields[0]
        if ($fields[1].Split("-")[1]) {
            $dockerImage | Add-Member -MemberType NoteProperty -Name Tag -Value $fields[1].Split("-")[0]
            $dockerImage | Add-Member -MemberType NoteProperty -Name Version -Value $fields[1].Split("-")[1]
            $dockerImage | Add-Member -MemberType NoteProperty -Name Major -Value $fields[1].Split("-")[1].Split(".")[0]
            $dockerImage | Add-Member -MemberType NoteProperty -Name Minor -Value $fields[1].Split("-")[1].Split(".")[1]
            $dockerImage | Add-Member -MemberType NoteProperty -Name Language -Value $fields[1].Split("-")[2]
        } else {
            $dockerImage | Add-Member -MemberType NoteProperty -Name Tag -Value $fields[1]
        }
        $dockerImage | Add-Member -MemberType NoteProperty -Name ID -Value $fields[2]
        $dockerImage | Add-Member -MemberType NoteProperty -Name Size -Value $fields[3]
        $dockerImage | Add-Member -MemberType NoteProperty -Name CreatedAt -Value ([DateTime]::ParseExact($fields[4].Substring(0, $dateTimeFormat.Length), $dateTimeFormat, $null))
        $dockerImages += $dockerImage
    }

    foreach ($dockerImage in ($dockerImages | Sort-Object -Property Version -Descending)) {
        $oldImages = $dockerImages | `
            Where-Object -Property Repository -eq $dockerImage.Repository | `
            Where-Object -Property Tag -EQ $dockerImage.Tag | `
            Where-Object -Property Major -EQ $dockerImage.Major | `
            Where-Object -Property Minor -EQ $dockerImage.Minor | `
            Where-Object -Property Language -EQ $dockerImage.Language | `
            Where-Object -Property Version -LT $dockerImage.Version
        $oldImages | % {
            if ($imagesToRemove -notcontains $($_.ID)) {
                $imagesToRemove += $($_.ID)
                Write-Host "Removing Docker Image $($_.ID)"
                try { docker image rm $($_.ID) }
                catch { Write-Host "Unable to remove Docker Image $($_.ID)" }
            }        
        }    
    }    
} else {
    Write-Host "Not Removing old Docker Images"
}

Flush-ContainerHelperCache -keepDays $keepDays