# Install the EXO V2 module if not already installed
if (!(Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement
}

# Connect to Exchange Online
Connect-ExchangeOnline -ShowProgress $true

# Prompt for the user's mailbox
$mailbox = Read-Host -Prompt "Enter the email address of the mailbox"

# Get the user's inbox rules
$rules = Get-InboxRule -Mailbox $mailbox

# List the user's inbox rules
$rules | Format-Table Name, Description

# Prompt for the rule to delete
$ruleName = Read-Host -Prompt "Enter the name of the rule to delete"

# Delete the specified rule
if ($rules.Name -contains $ruleName) {
    Remove-InboxRule -Mailbox $mailbox -Identity $ruleName -Confirm:$false
    Write-Output "Rule '$ruleName' has been removed."
} else {
    Write-Output "Rule '$ruleName' not found."
}

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false