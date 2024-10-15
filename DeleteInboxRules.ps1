# Install the EXO V2 module if not already installed
if (!(Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement
}

# Connect to Exchange Online
Connect-ExchangeOnline -ShowProgress $true

do {
    # Prompt for the user's mailbox
    $mailbox = Read-Host -Prompt "Enter the email address of the mailbox"

    # Get the user's inbox rules
    $rules = Get-InboxRule -Mailbox $mailbox

    if ($rules) {
        # List the user's inbox rules
        $rules | Format-Table Name, Description
        
        do {
            # Prompt for the rule to delete or skip
            $ruleName = Read-Host -Prompt "Enter the name of the rule to delete, or type 'skip' to skip"

            if ($ruleName -eq 'skip') {
                Write-Output "Skipping rule deletion for $mailbox."
                break  # Exit the inner loop to ask for another mailbox
            }

            # Delete the specified rule
            if ($rules.Name -contains $ruleName) {
                Remove-InboxRule -Mailbox $mailbox -Identity $ruleName -Confirm:$false
                Write-Output "Rule '$ruleName' has been removed."
            } else {
                Write-Output "Rule '$ruleName' not found."
            }

            # Ask if there are more rules to delete
            $moreRules = Read-Host -Prompt "Do you want to delete another rule for this mailbox? (yes/no)"
        } while ($moreRules -eq 'yes')

    } else {
        Write-Output "No inbox rules found for $mailbox."
    }

    # Ask if the user wants to look at another mailbox
    $moreMailboxes = Read-Host -Prompt "Do you want to manage rules for another mailbox? (yes/no)"
} while ($moreMailboxes -eq 'yes')

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false
