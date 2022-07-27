# Restore a specified SQL database to a specified folder on the same or different server, rename it, add it to an availability group.
# Used, for exemple, to "restage" the prod database to DEV/Qual
# Created by Christian Bocquet - https://www.linkedin.com/in/vchris/ and updated on 11.07.2022
# V3 for V11 and improvments, handling multiple NDF files
######################################################################################################
######################################################################################################
#See https://helpcenter.veeam.com/docs/backup/explorers_powershell/get-vesqldatabase.html?ver=110 for more options
######################################################################################################
# Variables to define per SQL Database to restore
$varvbrserver		             		="snfsrv795.snfbern.ch"
$varsource_vm         	         		= "SOURCEVMNAME"
$varsource_db_name  	        	    = "Databasename"
$varsource_instance_name     	        = "SOURCEINSTANCE"
$vartarget_db_name_extension            = "SUFFIXYOUWANT"
$vartarget_availability          	    = "AVAILABILITYGROUP"
$vartarget_vm          	         		= "TARGETVMNAME"
$vartarget_instance    	         	    = "TARGETINSTANCE"
$vartarget_foldermdf	         	    = "DRIVE:\DATAPATH\"
$vartarget_folderndf	         		= "DRIVE:\DATAPATH\"
$vartarget_folderldf	         		= "DRIVE:\LOGPATH\"
######################################################################################################
#Try to connect to the proper VBR server (this "try" compensate a bug that will be adressed in v12)
try {
    Connect-VBRServer -Server $varvbrserver
} catch {
    "Connect-VBRServer : Execution environment cannot be initialized to Remote" 
    break
}
######################################################################################################
# We define the restored database name and files name for primary files (MDF and LDF)
$vartarget_database    				    = "{0}{1}" -f $varsource_db_name, $vartarget_db_name_extension
$vartarget_mdf		    				= "{0}{1}{2}" -f $vartarget_foldermdf, $vartarget_database,".mdf"
$vartarget_ldf		    				= "{0}{1}{2}" -f $vartarget_folderldf, $vartarget_database,".ldf"
######################################################################################################
#Get the latest restore point for the selected VM and start a restore session
$varrestorepoint        				= Get-VBRApplicationRestorePoint -SQL | ? Name -match "^$varsource_vm" | Sort-Object –Property CreationTime –Descending | Select -First 1
Start-VESQLRestoreSession -RestorePoint $varrestorepoint
######################################################################################################
#Get the restore session running
$varsession 							= Get-VESQLRestoreSession
######################################################################################################
#Try to get the specified database from the last session
try {
    $vardatabase 						= Get-VESQLDatabase -Session $varsession[0] -Name $varsource_db_name -InstanceName $varsource_instance_name
} catch {
    "Couldnt find database" 
    break
}
######################################################################################################
#Obtain SQL files list from the backup
$vartarget_files 						= Get-VESQLDatabaseFile -Database $vardatabase
#Define the path for the primary files (MDF and LDF)
[String[]]$vartarget_path 		        = @($vartarget_mdf, $vartarget_ldf)
#If NDF files exists then add them to the destination path and increment the name of the files
for(($i=2), ($n=1); $i -lt $vartarget_files.Length; ($i++), ($n++)) { [String[]]$vartarget_path += "{0}{1}{2}{3}{4}" -f $vartarget_folderndf, $vartarget_database, "_", $n, ".ndf" }
######################################################################################################
#Show on the server what we are doing
write-host "Session: $varsession"
write-host "Database: $vardatabase"
write-host "Restorepoint :" $varrestorepoint.name $varrestorepoint.CreationTime
write-host "Target server / Instance / Availability Group : $vartarget_vm / $varsource_instance_name / $vartarget_availability"
write-host "Target files : $vartarget_path"
#Indicate the start time of the restore
write-host "Restore start time:"
get-date|write-host
######################################################################################################
#Restore the SQL Database to the designed SQL server with the defined settings, will overwrite existing database if the name already exist.
Restore-VESQLDatabase -Database $vardatabase -databasename $vartarget_database -ServerName $vartarget_vm -AvailabilityGroupName $vartarget_availability -InstanceName $vartarget_instance -File $vartarget_files -TargetPath $vartarget_path -Force 
######################################################################################################
#Post processing and cleaning
#Stop the session
Stop-VESQLRestoreSession -Session $varsession[0]
#Clean the variables
#Indicate the end time
write-host "Restore end time:"
get-date|write-host
#Disconnect VBR
Disconnect-VBRServer
