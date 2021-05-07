<#
    .SYNOPSIS
    Calls Home Assistant webhook endpoint when machine is locked/unlocked

    .DESCRIPTION
    Script can install itself as a sheduled task

    .PARAMETER HomeAssistantHost
    Home Assistant address (e.g. "192.168.1.2:8123")

    .PARAMETER HookName
    Hook name

    .PARAMETER Action
    Type of the action ("Locked" || "Unlocked")

    .PARAMETER Exec
    When used script issues HA request streight away

    .INPUTS
    None. You cannot pipe objects.

    .OUTPUTS
    None | ScheduledTask

    .EXAMPLE
    Script will ask whether to issue a HA request or setup scheduled task for 'OnWorkstationLocked' event
    PS> .\Invoke-WebhookOnLock.ps1 "192.168.1.2:8123" "device_lock" Locked
    

    .EXAMPLE
    Script will ask whether to issue a HA request or setup scheduled task for 'OnWorkstationUnlocked' event
    PS> .\Invoke-WebhookOnLock.ps1 "http://192.168.1.2:8123" "device_lock" Unlocked

    .LINK
    Github: https://github.com/maxwroc/Invoke-WebhookOnLock
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [String]$HomeAssistantHost,
    [Parameter(Mandatory = $true, Position = 1)]
    [String]$HookName,
    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateSet('Locked','Unlocked')]
    [String]$Action,
    [Parameter(Mandatory = $false)]
    [Switch]$Exec = $false
)


Function TriggerWebhook ($haHost, $haHookName, $action) {

    $body = @{
        device = $env:computername
        action = $action.ToLower()
    }


    if (-not $haHost.StartsWith("http")) {
        $haHost = "http://$($haHost)"
    }

    Invoke-WebRequest "$($haHost)/api/webhook/$($haHookName)" -Body ($body | ConvertTo-Json) -Method 'POST' -ContentType 'application/json'
}

Function RegisterTask($haHost, $haHookName, $action) {

    $taskSettings = New-ScheduledTaskSettingsSet
    $answer = Read-Host "Allow start if device is on batteries [y/n]"
    if ($answer -ieq "y") {
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
    }

    $argumentString = "-NoProfile -WindowStyle Hidden $($PSCommandPath) $($haHost) $($haHookName) $($action) -Exec"
    $taskAction = New-ScheduledTaskAction -Execute 'Powershell.exe' `
        -Argument $argumentString

    $TASK_SESSION_LOCK = 7
    $TASK_SESSION_UNLOCK = 8

    $state = $TASK_SESSION_LOCK
    if ($action -eq 'Unlocked') {
        $state = $TASK_SESSION_UNLOCK
    }

    $stateChangeTrigger = Get-CimClass `
        -Namespace ROOT\Microsoft\Windows\TaskScheduler `
        -ClassName MSFT_TaskSessionStateChangeTrigger

    $taskTrigger = New-CimInstance `
        -CimClass $stateChangeTrigger `
        -Property @{
            StateChange = $state  # TASK_SESSION_STATE_CHANGE_TYPE (taskschd.h)
        } `
        -ClientOnly
        
    $principal = New-ScheduledTaskPrincipal -UserId "$($env:USERDOMAIN)\$($env:USERNAME)" -RunLevel Highest
    $task = New-ScheduledTask `
        -Trigger $taskTrigger `
        -Action $taskAction `
        -Description "Notify Home Assistant on device $($action.ToLower())" `
        -Settings $taskSettings `
        -Principal $principal

    Register-ScheduledTask -InputObject $task -TaskName "HomeAssistant notify (device $($action.ToLower()))"
}






if ($Exec) {
    $answer = '1'
} else {
    Write-Host 'What do you want to do?'
    Write-Host
    Write-Host '1. Send event'
    Write-Host '2. Install as event triggered task'
    Write-Host 'q. Quit'

    $answer = Read-Host 'Please choose the action'
    Write-Host
}

switch ($answer) {
    '1' {
        TriggerWebhook $HomeAssistantHost $HookName $Action
    } '2' {
        RegisterTask $HomeAssistantHost $HookName $Action
    } default {
        exit
    }
}


