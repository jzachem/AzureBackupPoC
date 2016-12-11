# This is proof-of-concept of setup up Azure Backup for a single VM running on Hyper-V. 
# This PoC uses the Azure Resource Manager (ARM) interface, not the older (classic) Azure Service Manager (ASM) interface  

# Login to Azure 

# Todo - Get the Account info / credentials from a external file 
# For now just make the call and go through the portal login 

# Account related variables 

# $ProvidedAccountUserName = TODO - get the userid info from a local file not on GitHub.
$ProvidedSubscriptionName = "MSDN Platforms"

# Resource Group related variables 
$ProvidedResourceGroupName = "AzureBackupPoC" # Get from user provided parameters file 
$DefaultResourceGroupName = "AzureBackupPoC" 

# The variable is the preferred location for the Resource Group and its associated resources, such as the Recovery Vault 
$ProvidedRGLocation = "South Central US" # Get from user provided parameters file. Consider using the Azure constant instead of string. 
$DefaultRGLocation = "South Central US" 

# Passphare used for encryption and for decryption during data restore !!! Customer must remember or data cannot be restored!! 
$ProvidedPassphrase = "Complex!123_STRING"

Write-Host ("Attemping Login to Azure using the Account" + $ProvidedAccountUserName)

Login-AzureRmAccount

if ($true) # TODO Put into a Try-Catch
    {Write-Host ("Login Succeeded")}
else 
    {Write-Host ("Login Failed")} 

# Assume there are multiple subscriptions for this account, so we need to set the Azure Context
# to have to the right subscription 
 
# Query the subscription for the logged-in account to make sure the subscription to be used is in this acccount.
# TODO Handle the exception of the specificed subscription is not part of this account and let the user know why the program is terminating.

Write-Host ("Verifying the provided subscription is attached to the provided account") 

$UserSubscription = Get-AzureRmSubscription | where {$_.SubscriptionName -eq $ProvidedSubscriptionName}

# TBD = Check that this worked - Need to find out how to check or error 

if ($true) # TODO Put into a Try-Catch
    {Write-Host ("Subscription verified")}
else 
    {Write-Host ("The provided subscription is not associted with the provided account")} 


$UserSubscriptionID = $UserSubscription.SubscriptionId

# Set the context

Write-Host ("Attempting to set the Azure Resource Manager context to the Subscription Name " + $UserSubscription.SubscriptionName + "with ID " + $UserSubscription.SubscriptionId) 

# TODO see if Select-AzureRmSubscrition might be a better call than Set-AzureRmContext
Set-AzureRmContext -SubscriptionId $UserSubscriptionID 

# TBD Error Check 

Write-Host ("ARM Context successfully set to provided subscription") 


# Set the Azure Resource Manager Resource Group Name to be used 

if ($ProvidedResourceGroupName -ne $null)    
    {
    # TODO Determine is there is a way to pre-validate the string provided is a valid ResourceGroup name 
    Write-Host ("Using provided Azure Resource Group name") 
    $ResourceGroupName = $ProvidedResourceGroupName
    }    
else     
    {
    Write-Host ("No Resouce Group name provided, using default") 
    $ResourceGroupName = $DefaultResouceGroupName
    } 

# Set the Azure location (data center) where the Rource Group will be created

if ($ProvidedRGLocation -ne $null) 
    {
    # TODO Verify the provided location is a valid Azure location
    Write-Host ("Using provided location (data center) for Azure Resource Group creation") 
    $RGLocation = $ProvidedRGLocation
    }    
else 
    {
    Write-Host ("No Resouce Group creation location (data center) name provided, using default")
    $RGLocation = $DefaultRGLocation
    } 

# See if a resource group with the provided resouce group name already exists 
$RG = Get-AzureRmResourceGroup -Name $ResourceGroupName 

# TBD Determine existance based on $ResourceGroup object and exception from failure of call.  

# If the resource group does not already exist and the RG name and location have passed validation, create the new Resource Group. 
# if (TODO Do all the checks)  
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $RGLocation 

# TBD Error Check 

# Maybe do a Get-AzureRmResourceGroup after to doulble check the creation worked correctly and the RG really exists 

# Backup documentation says this is requied the first time Azure Recovery Services is used. # Backup docuematation say to be clear a Recovery Services Vault is NOT the same as a Backup Vault. # Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.RecoveryServices"
# The following URL will automaticatlly download the Azure Backup Agent "http://aka.ms/azurebackup_agent" from Microsoft Download Center
# Install by running c:\path\MARSAgentInstaller.exe /q to install with defaults. May also be silent install. 

#"This installs the agent with all the default options. The installation takes a few minutes in the background. If you do
# not specify the /nu option then the Windows Update window will open at the end of the installation to check for
# any updates. Once installed, the agent will show in the list of installed programs"
# The following addtionally switches allow the authenticated proxy information to be configurated duing Agent installation /ph,/po,/pu,/pw

# Need to do the PowerShell to do this download as part of the process, or prior to the process. May need to add authenticated proxy credentials to that action. 

Invoke-WebRequest -Uri "http://aka.ms/azurebackup_agent" -Outfile "C:\AzureVaultFiles\MARSAgentInstaller.exe" -UseBasicParsing

# Install the MARS agent 
# This worked, but a commmand windows popped up at one point, then went away. Need to find completely silent method 

Start-Process "c:\AzureVaultFiles\MARSAgentInstaller.exe" -ArgumentList "/q" -Wait -NoNewWindow 


# New-AzureRmRecoveryServicesVault -Name DRVault -ResourceGroupName RecoveryTest

$Vault = Get-AzureRmRecoveryServicesVault | where {$_.Name -eq "DRVault"} 


$credspath = "C:\AzureVaultFiles"
$credsfilename = Get-AzureRmRecoveryServicesVaultSettingsFile -Backup -Vault $Vault -Path $credspath 
Write-Host("The Vault Credentials File for the vault named " + $Vault +"were successfully downloaded.") Write-Host("The path to the Vault Credentials File credentials file is " + $credsfilename) Write-Host("The credentials in the file will expire in 48 hours.") # Need to install the backup agent first, I think. Didn't work before install. # Installed the app. Still failed, so will try importing the module # The MARS Installer (at least in /q quiet mode) does not add the location of it's PowerShell Module to the PSModulePath, so do it here. #Save the current value in the $p variable.

$p = [Environment]::GetEnvironmentVariable("PSModulePath")

#Add the new path to the $p variable. Begin with a semi-colon separator.

$p += ";C:\Program Files\Microsoft Azure Recovery Services Agent\bin\Modules"

#Add the paths in $p to the PSModulePath value.
[Environment]::SetEnvironmentVariable("PSModulePath",$p)Import-Module MSOnlineBackup # Check that is worked $moduleName = Get-Module -ListAvailable | where {$_.Name -eq "OBOnlineBackup"} if ($moduleName.Name -eq $null)     {Write-Host ("Module OBOnlineBackup was NOT sucessfully imported")}else     {    if ($moduleName.Name -eq "OBOnlineBackup")         {Write-Host ("Module OBOnlineBackup sucessfully imported")}    else         {Write-Host ("Shouldn't get here")}    }# Registration uses the value credential obtained above. Credentials are only good for 48 hours. # Shouldn't matter for script, but mentioned here in case the call is made later for some reason and fails.# First run got this, ran again a minute later and it worked correctly with no warning or error.  # This is same operation that requried three tries when I did it from the GUI on a different machine. ## Vault credentials validation succeeded. Below are the backup vault details. 
#
# CertThumbprint      : c5259b4e3184eedf7fbd95c32cc36306a41c864b
# SubscriptionID      : 8578a82c-0cc2-4ed3-8a59-a5fa13d4b519
# ServiceResourceName : DRVault
# Region              : eastus
# Machine registration succeeded.
# WARNING: Existing policy found. Failed to enable scheduled backup according to the policy.
# Start-OBRegistration : The current operation failed due to an internal service error [0x7DC]. Please retry the operation after sometime. If the issue persists, please contact Microsoft Support.
# At line:1 char:1
# + Start-OBRegistration -VaultCredentials $credsfilename.FilePath -Confi ...
# + ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#     + CategoryInfo          : NotSpecified: (:) [Start-OBRegistration], DlsException
#     + FullyQualifiedErrorId : CBPGenericOperationFailure,Microsoft.Internal.CloudBackup.Commands.StartCBRegistrationCommand## TODO Handle this expection with a multiple retry Start-OBRegistration -VaultCredentials $credsfilename.FilePath -Confirm:$FALSE 
# Set the proxy details
# Can set proxy values with switches duing MARS Agent install, or later here with PS.  

Set-OBMachineSetting -NoProxy # This is for home only. 

# Set bandwidth details 

Set-OBMachineSetting -NoThrottle # TODO - Need to experiment with options of this setting.

#!!!!! Setting the passphrase !!!!!!!
# The backup data sent to Azure Backup is encrypted to protect the confidentiality of the data. The encryption
# passphrase is the "password" to decrypt the data at the time of restore.# IMPOTANT Keep the passphrase information safe and secure once it is set. You will not be able to restore data from Azure without this passphrase.ConvertTo-SecureString -String $ProvidedPassphrase -AsPlainText -Force | Set-OBMachineSetting# Configure the backup policy# First create a new policy object $newpolicy = New-OBPolicy  New-OBPolicy -# Configure the backup schedule $sched = New-OBSchedule -DaysOfWeek Tuesday -TimesOfDay 5:00# Now associate the schedule with the policy Set-OBSchedule -Policy $newpolicy -Schedule $sched# Set the retention policy $retentionPolicy = New-OBRetentionPolicy -RetentionDays 7Set-OBRetentionPolicy -Policy $newpolicy -RetentionPolicy $retentionPolicy $inclusions = New-OBFileSpec -FileSpec "C:\Users\Win10-Dev\Documents\VirtualNetworkStuff.ps1"Add-OBFileSpec -Policy $newpolicy -FileSpec $inclusions#check for existing policy and if it exists remove it #Get-OBPolicy | Remove-OBPolicy # Set the policy Set-OBPolicy -Policy $newpolicy# Do an adhoc backup Get-OBPolicy | Start-OBBackup










