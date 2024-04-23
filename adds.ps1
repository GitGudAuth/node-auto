# Check if Organizational Unit (OU) already exists
function OUExists {
    param (
        [string]$ouName
    )
    $ou = Get-ADOrganizationalUnit -Filter { Name -eq $ouName } -ErrorAction SilentlyContinue
    return $ou -ne $null
}

# Check if Group already exists
function GroupExists {
    param (
        [string]$groupName
    )
    $group = Get-ADGroup -Filter { Name -eq $groupName } -ErrorAction SilentlyContinue
    return $group -ne $null
}

# Check if User already exists
function UserExists {
    param (
        [string]$username
    )
    $user = Get-ADUser -Filter { SamAccountName -eq $username } -ErrorAction SilentlyContinue
    return $user -ne $null
}

function AD-OusGroupsUsers {
    importmod
    $scriptDir = Get-ScriptDirectory
    $excelFileName = Read-Host "Please enter the Excel file name "
    if (-not $excelFileName.EndsWith(".xlsx")) {
        $excelFileName += ".xlsx"
    }
    $excelFilePath = Join-Path -Path $scriptDir -ChildPath $excelFileName
    if (Test-Path $excelFilePath) {
        $ouData = Import-Excel -Path $excelFilePath -WorksheetName "OUData"
        $gpData = Import-Excel -Path $excelFilePath -WorksheetName "GPData"
        $userData = Import-Excel -Path $excelFilePath -WorksheetName "USERData"
        Start-Sleep -Seconds 2
    } else {
        Write-Host "Your file not found at $excelFilePath"
        Start-Sleep -Seconds 2
    }
    try {
        # Create Main OU
        $rqou = Read-Host "Continue To Create OUs ? (Yes/No)"
        if ($rqou -eq "" -or $rqou.ToUpper() -eq "YES" -or $rqou.ToUpper() -eq "Y") {
            foreach ($row in $ouData) {
                $ouM = $row.OUMain
                $ouPathM = $row.Domain

                if (-not (Get-ADOrganizationalUnit -Filter { Name -eq $ouM })) {
                    New-ADOrganizationalUnit -Name $ouM -Path $ouPathM -ErrorAction SilentlyContinue
                    Write-Host "Main OU created: $ouM, $ouPathM"
                } else {
                    Write-Host "OU $ouM already exists."
                }
            }

            # Loop through each row in the OU data
            foreach ($row in $ouData) {
                $ouName = $row.OUName
                $ouPath = "OU=$ouM,$ouPathM"

                if (-not (Get-ADOrganizationalUnit -Filter { Name -eq $ouName })) {
                    New-ADOrganizationalUnit -Name $ouName -Path $ouPath -ErrorAction SilentlyContinue
                    Write-Host "Secondary OU created: $ouName, $ouPath"
                } else {
                    Write-Host "OU $ouName already exists."
                }

                # Create child OUs if available
                if ($row.ChildOUs) {
                    foreach ($childOUName in $row.ChildOUs.Split(',')) {
                        $childOUPath = "OU=$ouName,$ouPath"

                        if (-not (Get-ADOrganizationalUnit -Filter { Name -eq $childOUName })) {
                            New-ADOrganizationalUnit -Name $childOUName -Path $childOUPath -ErrorAction SilentlyContinue
                            Write-Host "Child OU created: $childOUName, $childOUPath"
                        } else {
                            Write-Host "OU $childOUName already exists."
                        }
                    }
                }
            }
            Start-Sleep -Seconds 2
            $rqG = Read-Host "Continue To Create Groups ? (Yes/No)"
            if ($rqG -eq "" -or $rqG.ToUpper() -eq "YES" -or $rqG.ToUpper() -eq "Y") {
                foreach ($row in $gpData) {
                    $ouGroup = $row.Group
                    $ouChild = $row.ChildOUs
                    $ouName = $row.OUName
                    $ouM = $row.OUMain
                    $domain = $row.Domain

                    # Set group details
                    $groupName = "$ouGroup"
                    $groupPathBase = "OU=$ouName,OU=$ouM,$domain"
                    $groupPath = if ($ouChild -and (Get-ADOrganizationalUnit -Filter { Name -eq $ouChild })) {
                                    "OU=$ouChild,$groupPathBase"
                                 } else {
                                    $groupPathBase
                                 }
                    # Create the group
                    if (-not (Get-ADGroup -Filter { SamAccountName -eq $groupName })) {
                        # Create the group
                        New-ADGroup -Name $groupName -SamAccountName $groupName -GroupCategory Security -GroupScope Global -Path $groupPath
                        Write-Host "Group created: $groupName, $groupPath"
                    } else {
                        Write-Host "Group $groupName already exists."
                    }
                } #ousgusers
                Start-Sleep -Seconds 2
                $rqUs = Read-Host "Continue To Create Users ? (Yes/No)"
                if ($rqUs -eq "" -or $rqUs.ToUpper() -eq "YES" -or $rqUs.ToUpper() -eq "Y") {
                    foreach ($userRow in $userData) {
                        $firstName = $userRow.FirstName
                        $lastName = $userRow.LastName
                        $username = $userRow.Username
                        $upn = $userRow.upn
                        $password = $userRow.Password
                        $ouGroup = $userRow.Group
                        $ouChild = $userRow.ChildOUs
                        $ouName = $userRow.OUName
                        $ouM = $userRow.OUMain
                        $domain = $userRow.Domain
                        $ouPathBase = "OU=$ouName,OU=$ouM,$domain"
                        $ouPath = if ($ouChild -and (Get-ADOrganizationalUnit -Filter { Name -eq $ouChild })) {
                                      "OU=$ouChild,$ouPathBase"
                                  } else {
                                      $ouPathBase
                                  }
                        $Email = $userRow.Email
                        if (-not (Get-ADUser -Filter { SamAccountName -eq $username })) {
                            # Create the user
                            New-ADUser -Name $username -GivenName $firstName -Surname $lastName -SamAccountName $username -EmailAddress $Email -UserPrincipalName "$username@$upn" -Enabled $true -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) -ChangePasswordAtLogon $true -Path $ouPath
                            Write-Host "User created: $username"
                        } else {
                            Write-Host "User $username already exists."
                        }

                        # Add user to groups
                        try {
                            Add-ADGroupMember $ouGroup $username
                            Write-Host "User $username added to group $ouGroup"
                        } catch {
                            Write-Host "Failed to add user $username to group $ouGroup"
                        }
                    }
                    Start-Sleep -Seconds 5
                } else {
                    Write-Host "Exit Users creation"
                    Start-Sleep -Seconds 2
                }
            } else {
                Write-Host "Exit Groups creation"
                Start-Sleep -Seconds 2
            }
        } else {
            Write-Host "Exit to main menu"
            Start-Sleep -Seconds 2
        }
    } catch {
        Write-Host "An error occurred: $_"
        Start-Sleep -Seconds 5
    }
}

# Import modules
function importmod {
    try {
        if (-not (Get-Module -Name ImportExcel -ListAvailable)) {
            Write-Host "You need to Install Excel module for this Script to Work"
            Install-Module -Name ImportExcel -Scope CurrentUser
            Start-Sleep -Seconds 2
        } else {
            Import-Module -Name ImportExcel
            Write-Host "Check (1) success"
        }
        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            Write-Host "Active Directory module is not available or not installed."
            Start-Sleep -Seconds 2
        } else {
            Import-Module -Name ActiveDirectory
            Write-Host "Check (2) success"
        }
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "Something went wrong! Details: $_.Exception.Message"
        Write-Host "Maybe check your internet ?"
        Write-Host "Or Policy ?"
        Write-Host "Is Domain Controller installed ?"
        Write-Host "You can also contact me."
        Start-Sleep -Seconds 5
    }
}

# Get Script Working Directory
function Get-ScriptDirectory {
    Split-Path -Parent $PSCommandPath
    Start-Sleep -Seconds 2
}

# Check XLXS file Validation
function xlxsfilevald {
    $scriptDir = Get-ScriptDirectory
    $excelFileName = Read-Host "Please enter the Excel file name : "
    # Check if the user input ends with .xlsx
    if (-not $excelFileName.EndsWith(".xlsx")) {
        $excelFileName += ".xlsx"
    }
    $excelFilePath = Join-Path -Path $scriptDir -ChildPath $excelFileName

    if (Test-Path $excelFilePath) {
        Write-Host "Your file found at $excelFilePath"
        Start-Sleep -Seconds 2
    } else {
        Write-Host "Your file not found at $excelFilePath"
        Start-Sleep -Seconds 2
    }
}

# Check Internet
function internetcheck {
	Write-Host ""
	Write-Host "Checking Internet."
	$pingre1 = Test-Connection -ComputerName 8.8.8.8 -Count 4
	$pingre2 = Test-Connection -ComputerName google.com -Count 4
	
	if ( $pingre1 -and $pingre2 ) {
		Write-Host "Internet Working !"
		Start-Sleep -Seconds 1
	}
	else {
		Write-Host "No Internet Access."
		Write-Host "Please Connect to Internet"
		Start-Sleep -Seconds 1
	}
}

# Rename Server
function basicfiguration {
    try {
        internetcheck
        ipconfig /all
        Write-Host "Current configuration.`n"
        $strcfg = Read-Host "Begin to config this computer (Yes/No)"
        if ($strcfg -eq "" -or $strcfg.ToUpper() -eq "YES" -or $strcfg.ToUpper() -eq "Y") {
            $svname = Read-Host "Enter name for this computer"
            Rename-Computer -Confirm -NewName $svname
            Get-NetAdapter
            $infdex = Read-Host "Enter Interface Index"
            $IPType = Read-Host "Enter IPv4 Or IPv6"
            $enterip = Read-Host "Enter IP Your Address"
            $defgate = Read-Host "Enter Gateway IP Address"
            $prelength = Read-Host "Enter Prefix length"
            $dnsserver1 = Read-Host "Enter IP Address for DNS Server 1"
            $dnsserver2 = Read-Host "Enter IP Address for DNS Server 2"
            $dnsAddresses = @($dnsserver1, $dnsserver2)

            $continueornot = Read-Host "Continue ? (Yes/No)"
            if (@("No", "n", "no") -contains $continueornot.ToLower()) {
                Write-Host "Returning to main menu..."
                Write-Host ""
                Start-Sleep -Seconds 1
            } else {
                $adapter = Get-NetAdapter | ? {$_.Status -eq "up"}
                If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
                    $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
                }
                If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
                    $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
                }
                New-NetIPAddress -InterfaceIndex $infdex -AddressFamily $IPType -IPAddress $enterip -PrefixLength $prelength -DefaultGateway $defgate
                #New-NetIPAddress -InterfaceIndex $infdex -IPAddress $enterip -DefaultGateway $defgate -PrefixLength $prelength
                Write-Host "Set IP Address success !"
                Write-Host "`n"
                Start-Sleep -Seconds 1
                Set-DnsClientServerAddress -InterfaceIndex $infdex -ServerAddresses $dnsAddresses
                Write-Host "Set DNS Server success !"
                Write-Host "`n"
                Start-Sleep -Seconds 2
                Write-Host "Current Cofiguration: "
                Write-Host "`n"
                ipconfig /all
		        Start-Sleep -Seconds 5
                Write-Host "`n"
		        $rst = Read-Host "Restart Your Computer to Apply Changes (Yes/No)"
                if ($rst -eq "" -or $rst.ToUpper() -eq "YES" -or $rst.ToUpper() -eq "Y") {
                    Write-Host "Shutting down..."
                    Start-Sleep -Seconds 2
                    shutdown -r -f -t 0
                } else {
                    Write-Host "Exit to main menu"
                    Start-Sleep -Seconds 2
                }
            }
        } else {
            Write-Host "Exit to main menu"
            Start-Sleep -Seconds 2
        }
    }
    catch {
        "Something wrong, please check input !"
		"Is your input IP Address correct ?"
        Start-Sleep -Seconds 5
    }
}

# Install Active Directory Domain Services
function addsinstall {
    try {
		Write-Host "Start Installing Active Directory Domain Services."
		Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
		Write-Host "Start Installing Feature Active Directory Domain Services Complete."
		$yourdomain
	do {
			$yourdomain = Read-Host "Enter your domain name "
			if (validdn -domainName $yourdomain) {
				Write-Host "Valid Domain Name"
				Write-Host "Your Domain Name is $yourdomain"
				Start-Sleep -Seconds 1
				$valid = $true
			} else {
				Write-Host "Invalid Domain Name"
				Write-Host "Error: $_"
				Write-Host "You also need to input a valid domain Example: 'abc.com' or 'adatum.com'."
				Write-Host "Try again"
				$valid = $false
			}
		} until ($valid)
		$choices = Read-Host "Coutinue ADDS Installation ? (Yes/No)"
			if ( $choices -in "Yes", "Y", "y", "yes") {
				<#Write-Host "Start Configurating Domain Name And Additional Service."
				Install-ADDSForest -DomainName $yourdomain -InstallDNS
				Write-Host "Machine will be restarted soon."#>
                do {
                    $adRole = Read-Host "Do you want to install a Primary Domain Controller (PDC) or an Additional Domain Controller (ADC)? (PDC/ADC/Exit)"
    
                    if ($adRole -eq "PDC") {
                        Write-Host "Start Configurating Primary Domain Controller (PDC) and Additional Service."
                        Install-ADDSForest -DomainName $yourdomain -InstallDNS
                        Write-Host "Machine will be restarted soon."
                        $validRole = $true
                    } elseif ($adRole -eq "ADC") {
                        Write-Host "Start Configurating Additional Domain Controller (ADC)."
                        $HashArguments = @{
                            Credential = (Get-Credential)
                            DomainName = $yourdomain
                            InstallDns = $true
                        }
                        Install-ADDSDomainController $HashArguments
                        Write-Host "Machine will be restarted soon."
                        $validRole = $true
                    } elseif ($adRole -eq "Exit") {
                        Write-Host "Exiting..."
                        return
                    } else {
                        Write-Host "Invalid choice. Please enter either 'PDC', 'ADC', or 'Exit'."
                        $validRole = $false
                    }
                } while (-not $validRole)
			} else {
				Write-Host "Your answer is No"
				Write-Host "Return to main menu..."
				Start-Sleep -Seconds 2
			}
    }
    catch {
		"Something went wrong installing ADDS, check your input !"
		"You also need to input a valid domain Example: 'abc.com' or 'adatum.com'."
		"Try again"
        Start-Sleep -Seconds 5
    }	
}

# Validate Input Domain Name

function validdn {
    param (
        [string]$domainName
    )

    # Regular expression pattern to match a valid domain name
    $pattern = "^(?=.{1,253}\.?$)(?:(?!-|[^.]+\.--|^\.)[a-zA-Z0-9\-]{1,63}(?<!-)(?:\.|$)){1,127}$"

    if ($domainName -match $pattern) {
        return $true
    } else {
        return $false
    }
}

# Main Menu
function mainMenu {
	Clear-Host
	Write-Host `n
	Write-Host `n
	Write-Host `n
	Write-Host `n
	Write-Host "       _____________________________________________________________________`n"
	Write-Host `n
	Write-Host "                              Choose your options:`n"
	Write-Host `n
	Write-Host "              [1] Check Current Working Directory`n"
	Write-Host "              [2] Check Internet Connection`n"
	Write-Host "              [3] Basic Configuration`n"
	Write-Host "              [4] Install Active Directory Domain Services`n"
	Write-Host "              [5] OUs, Groups, Users Create with Scripting`n"
	Write-Host `n
	Write-Host "       ______________________________________________________________________`n"
	Write-Host `n
	Write-Host `n
	Write-Host `n
}

# Submenu For OUs, Groups, Users Creation
function subMenu1 {
	Clear-Host
	Write-Host `n
	Write-Host `n
	Write-Host `n
	Write-Host `n
	Write-Host "       _____________________________________________________________________`n"
	Write-Host `n
	Write-Host "                              Choose your options:`n"
	Write-Host `n
	Write-Host "                    [1] Check XLXS File Validation`n"
    Write-Host "                    [2] Import or Check Require Modules`n"
    Write-Host "                    [3] Create OUs, Groups and Users`n"
	Write-Host `n
	Write-Host "       ______________________________________________________________________`n"
	Write-Host `n
	Write-Host `n
	Write-Host `n
}

while ($true) {
	mainMenu
	$choice = Read-Host "Enter your choice (1-5), or 'q' to quit"
	switch ($choice) {
        '1' {
            Get-ScriptDirectory
        }
        '2' {
            internetcheck
		}
        '3' {
            basicfiguration
		}
		'4' {
            addsinstall
		}
        '5' {
            while ($true) {
                submenu1
                $subChoice = Read-Host "Enter your choice (1-6), or 'q' to go back to Main Menu"
                switch ($subChoice) {
                    '1' {
                        xlxsfilevald
                    }
                    '2' {
                        importmod
                    }
                    '3' {
                        AD-OusGroupsUsers
                    }
                    'q' {
                        $ExitFlag = $true
                        break
                    }
                    default {
                        Write-Host "Invalid choice. Please choose an option from 1 to 3, or 'q' to return to main Menu"
                        Start-Sleep -Seconds 2
                    }
                }
                if ($ExitFlag) {
                    break
                }
            }
        }
		'q' {
			Write-Host "Thanks for using this script, github.com/GitGudAuth"
			Write-Host "Exiting Script..."
			return
		}
		default {
		    Write-Host "Invalid choice. Please choose an option from 1 to 3, or 'q' to quit"
		    Start-Sleep -Seconds 2
		}
	}
}