Echo ""
Echo ""
Echo "This program is designed to export a Windows VM from Hyper-V to Azure."
Echo ""
Echo "This Process may take several hours to complete"
Echo ""
Echo "Please Run sysprep on the VM before using this program."
Echo ""


$vhd = Read-Host "Where is the VHD located?"
$vhdfileinfo = dir $vhd
$vhdextension = $vhdfileinfo.Extension

#make sure Extension is correct
If ($vhdextension -eq ".vhd") {echo "The extension is .vhd, continuing"}
#Need to Convert .vhdx to .vhd
Elseif ($vhdextension -eq ".vhdx") 
{
	echo "We will need to convert the .vhdx file to .vhd, this may take a while"
	Read-Host "Press enter to begin converting"
	
	$newVHD = $vhd.Substring(0,$vhd.Length-1)
	
	Convert-VHD $vhd $newVHD
	
	$vhd = $newVHD
	
	echo "Converted vhdx to vhd, currently using $vhd"
		
}
#File Extension not valid
Else 
{
	echo "invalid file extension, pls try again"
	Read-Host "Press enter to exit"
	Exit
}
#Prompts user to log into Azure Account
Add-AzureAccount

Echo " "
Echo " "
Echo "Your Subcriptions are being gathered..."
Echo " "
Echo "Please Select your Subscription"
Echo "------------------------------------"
Echo " "

#Lists Subscriptions
$count = 0;
Get-AzureSubscription | ForEach-Object {Write-Host ($count+1) : $_.SubscriptionName -NoNewline 
	Echo " "
	$count++ }

Echo " "
$SubNumber = Read-Host "Please Enter the Number of the Subscription"
$AzureSubName = (Get-AzureSubscription)[$SubNumber-1].SubscriptionName
Select-AzureSubscription -SubscriptionName $AzureSubName

Echo " "
Echo " "
Echo "Your Storage Accounts are being gathered..."
Echo " "
Echo "Please Select your Storage Account"
Echo "------------------------------------"
Echo " "

#Gets rid of annoying warning messages
$WarningPreference = "SilentlyContinue"

#Lists Storage Accounts Associated with Subscription
$count = 0;
Get-AzureStorageAccount | ForEach-Object {Write-Host ($count+1) : $_.StorageAccountName -NoNewline 
	Echo " "
	$count++ }

Echo " "
Echo "Please Enter the Number of the Storage Account"
$SubNumber = Read-Host "or type NEW to make a new Storage Account"

#Create a New Azure Storage Account, and Set AzureSAName equal to the new account.
IF ($SubNumber -eq "NEW")
{
	Echo "------------------------------------"
	Echo "no Upper case characters are allowed, if they are entered they will be changed to lower"
	$AzureSAName = Read-Host "Enter the Name of the new Storage Account"
	$SALocation = Read-Host "Enter The Location of the Storage Account"
	New-AzureStorageAccount -StorageAccountName $AzureSAName -Location $SALocation
}
#If not, Selects the Storage Account and sets the Location
ELSE
{
$AzureSAName = (Get-AzureStorageAccount)[$SubNumber-1].StorageAccountName
Set-AzureSubscription -CurrentStorageAccountName $AzureSAName -SubscriptionName $AzureSubName
$SALocation = Get-AzureStorageAccount -StorageAccountName $AzureSAName | Select -ExpandProperty Location
}

Echo " "
Echo " "
Echo "Your Containers are being gathered..."
Echo " "
Echo "Please Select your container"
Echo "------------------------------------"
Echo " "



#List storage containers in storage account
$count = 0;
Get-AzureStorageContainer | ForEach-Object {Write-Host ($count+1) : $_.Name -NoNewline 
	Echo " "
	$count++ }

Echo " "
Echo "Please Enter the Number of the Container"
$SubNumber = Read-Host "Or Type NEW to Create a Container"

#Create a New Container if needed
IF ($SubNumber -eq "NEW")
{
	Echo "------------------------------------"
	Echo "no Upper case characters are allowed, if they are entered they will be changed to lower"
	$AzureContainerName = Read-Host "Enter the Name of the new Storage Container"
	New-AzureStorageContainer -Name $AzureContainerName.ToLower() -Permission Off
}
#Set container name
ELSE
{
$AzureContainerName = (Get-AzureStorageContainer)[$SubNumber-1].Name
}

Echo ""
$VHDuploadname = Read-Host "Enter the Name to call the VHD in Azure"
Echo "Uploading VHD to Azure, this may take a while...."

#Sets the URL
$AzureDestination = "https://"+$AzureSAName+".blob.core.windows.net/"+$AzureContainerName+"/"+$VHDuploadname+".vhd"

#uploads the .vhd file to azure blob storage
Add-AzureVhd -Destination $AzureDestination -LocalFilePath $VHD

$IMGname = $VHDuploadname

#Allows the .vhd file to be copied into a base image
Add-AzureVMImage -ImageName $IMGname -Medialocation $AzureDestination -OS "Windows"

Echo "The VHD has been uploaded and set as an Azure VM Image, now we need some information"
Echo ""

$VMname = Read-Host "Please Enter the Name of the VM"
$InstanceSize = Read-Host "Please enter the size of the VM (Basic_A0-Basic-A4, A5-A11, ect..)"
$adminusername = Read-Host "Enter the Admin UserName"
$adminpw = Read-Host "Enter the Admin Password, must contain at least 1 capital and 1 character"

#Gathers the data for the VM
$newVM = New-AzureVMConfig -Name $VMname -InstanceSize $InstanceSize -ImageName $IMGname | Add-AzureProvisioningConfig -Windows -AdminUsername $adminusername -Password $adminpw

#Initializes the VM
New-AzureVM -ServiceName $VMname -VMs $newVM -Location $SALocation

#Start the VM
Start-AzureVM -ServiceName $VMname -Name $VMname

Echo "Success!"

Read-Host "Press enter to exit"





