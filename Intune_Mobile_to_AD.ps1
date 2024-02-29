Import-Module ActiveDirectory

$clientId = ""
$clientSecret = ""
$tenantId = ""
$scope = "https://graph.microsoft.com/.default"

$authority = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$authBody = @{
    "grant_type" = "client_credentials";
    "client_id" = $clientId;
    "client_secret" = $clientSecret;
    "scope" = $scope
}

try {
    $authResponse = Invoke-RestMethod -Method Post -Uri $authority -Body $authBody
    $accessToken = $authResponse.access_token
    Write-Host "Successfully retrieved access token."
} catch {
    Write-Warning "Failed to get access token: $($_.Exception.Message)"
    exit
}

function Format-PhoneNumber {
    param ([string]$phoneNumber)
    $phoneNumber = $phoneNumber -replace '\D'
    if ($phoneNumber.Length -eq 10) {
        return "($($phoneNumber.Substring(0,3))) $($phoneNumber.Substring(3,3))-$($phoneNumber.Substring(6))"
    } elseif ($phoneNumber.Length -eq 11 -and $phoneNumber.StartsWith("1")) {
        return "($($phoneNumber.Substring(1,3))) $($phoneNumber.Substring(4,3))-$($phoneNumber.Substring(7))"
    } else {
        return $phoneNumber
    }
}

function Update-ADUserMobile {
    param (
        [string]$emailAddress,
        [string]$phoneNumber
    )
    $adUser = Get-ADUser -Filter "mail -eq '$emailAddress'" -Properties MobilePhone
    if ($adUser) {
        $currentMobilePhone = $adUser.MobilePhone -as [string]
        $currentMobilePhone = $currentMobilePhone.Trim()

        if (-not $currentMobilePhone) {
            Set-ADUser -Identity $adUser.DistinguishedName -MobilePhone $phoneNumber
            Write-Host "Updated AD user ($emailAddress) mobile phone to $phoneNumber."
        } else {
            Write-Host "AD user ($emailAddress) already has a mobile phone number set to $currentMobilePhone. No update needed."
        }
    } else {
        Write-Host "AD user with email $emailAddress not found."
    }
}


function Get-NewADUsers {
    $dateLimit = (Get-Date).AddDays(-10)
    Get-ADUser -Filter {whenCreated -ge $dateLimit} -Properties mail, whenCreated | Where-Object { $_.mail -ne $null }
}

function Query-ManagedDevices {
    param ($Uri, $Headers, $emailAddress)
    
    do {
        $response = Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers
        foreach ($device in $response.value) {
            if ($device.userPrincipalName -eq $emailAddress -or $device.emailAddress -eq $emailAddress) {
                $formattedPhoneNumber = Format-PhoneNumber -phoneNumber $device.phoneNumber
                Update-ADUserMobile -emailAddress $emailAddress -phoneNumber $formattedPhoneNumber
                return $true
            }
        }
        $Uri = if ($response.'@odata.nextLink') { $response.'@odata.nextLink' } else { $null }
    } while ($Uri)
    
    return $false
}

$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Accept" = "application/json"
}

$uriBase = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=id,userDisplayName,userPrincipalName,emailAddress,operatingSystem,enrolledDateTime,phoneNumber,deviceName"

$newUsers = Get-NewADUsers
foreach ($user in $newUsers) {
    $uri = $uriBase + "&`$filter=userPrincipalName eq '" + $user.mail + "'"
    $deviceFound = Query-ManagedDevices -Uri $uri -Headers $headers -emailAddress $user.mail

    if (-not $deviceFound) {
        Write-Host "No matching device found for $($user.mail)."
    }
}
