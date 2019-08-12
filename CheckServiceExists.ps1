#Function to check if a service exists.
$servicename = 'servicename'
function Confirm-WindowsServiceExists($servicename){
    if(Get-Service -name $servicename -ErrorAction SilentlyContinue){
        return $true
    }else {
        return $false
    }
}

$result = Confirm-WindowsServiceExists($servicename)

if($result){
    Write-Output "Service already exists"
}else{
    Write-Output "Service does not exist"
}