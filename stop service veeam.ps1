$ServiceList = Get-Service "veeam*" | format-list Name
foreach ($service in $ServiceList)
{
Get-Service -ServiceName $service | stop-Service
Get-Service -ServiceName $service | set-Service -StartupType disabled
Get-WmiObject Win32_Service |Where-Object {$_.name -eq $Service}|Format-List -Property Name,Startmode,State
}