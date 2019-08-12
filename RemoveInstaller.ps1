
# Local Variables
$cred = Get-Credential
$computername = Get-Content servers.txt
$installer = 'ApplicationFolder\install.msi'
$source = 'SourceFilesPath'
$destinationfolder = "$env:TEMP\Install"

# If error is detected stop script
$ErrorActionPreference = 'Stop'

# loop through every computer in the file
foreach ($computer in $computername){
    Write-Output "Beginning work on $computer."

    # Establish session with remote computers
    $session = New-PSSession -ComputerName $computer -Credential $cred

    Invoke-Command -Session $session -ScriptBlock{
        
        # Session variables
        $group = 'Administrators'
        $member = 'domain\user'
        
        # Check if install dir is present on remote computer, if not create it.
        if (!(Test-Path -Path $Using:destinationfolder)){
            New-Item $Using:destinationfolder -ItemType Directory
            Write-Output "Creating TEMP install directory."
        }
        
        # Save group members of remote computers group
        $groupmembers = Get-LocalGroupMember $group | Select-Object -ExpandProperty Name
        
        # Check if member if part of the groupmembers variable, if not add member.
        if (!($groupmembers -contains $member)){
            Add-LocalGroupMember -Group $group -Member $member
            Write-Output "Added $member to local $group group."
        }
    }

    $result = Invoke-Command -Session $session -ScriptBlock{
        # Service we want to check that is installed.
        $servicename = 'ServiceName'

        # Function that is returning $true if service exists and $false if it does not.
        function Confirm-WindowsServiceExists($servicename){
          if(Get-Service -name $servicename -ErrorAction SilentlyContinue){
                return $true
           }else {
                return $false
           }
        }
        Confirm-WindowsServiceExists($servicename)
    }

    # Copy source files to session computer & install application
    $install = if($result){
        Write-Output "$servicename already installed"
    } else {
        Copy-Item -Path $source -Destination $destinationfolder -ToSession $session -Recurse -Force
        Write-Output 'Installation files have been copied.'
        <# 
        Set remote executable
        Creates log file
        Set argument parameters
        Begin remote installation & wait for process to finish
        #>
        Invoke-Command -Session $session -ScriptBlock{
            $install = "$using:destinationfolder\$Using:installer"
            New-Item -Path "$using:destinationfolder\log.txt" -ItemType File
            $log = "$using:destinationfolder\log.txt" 
            $param = "/QN /L*V $log"
            Start-Process $install -ArgumentList $param -Wait
            Write-Output "Installation has completed on $Using:computer"
        }
    }

    # Remove session
    Remove-PSSession $session
    
    # Waits 60 seconds after install and reboots server and waits for it to come back online
    If ($install -eq "$servicename already installed"){
        Write-Output 'Skipping reboot.'
    } else {
        Write-Output 'Waiting 1 min to initiate reboot.'
        Start-Sleep -Seconds 60
        Write-Output "Rebooting $computer"
        Restart-Computer -ComputerName $computer -Credential $cred -Protocol WSMan -Wait -Force
        Write-Output "$computer successfully rebooted."
        
        # Removes installer files from remote computer
        Invoke-Command -ComputerName $computer -ScriptBlock {Remove-Item -Path "$env:TEMP\Install" -Recurse -Force} -Credential $cred
        Write-Output "$computer's temp install files have been removed proceeding with next server."
    }
}
