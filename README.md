# Invoke-WebhookOnLock
Script for calling HomeAssistant webhook when Win workstation is (un)locked

### Installation

```powershell
.\Invoke-WebhookOnLock.ps1 -HomeAssistantHost 192.168.1.2:8123 -HookName device_lock -Action Locked
```

Script will ask you whether you want to make a test call or setup a system task. Before setting up the task use the first option and check if call was received by HA.

![image](https://user-images.githubusercontent.com/8268674/117484289-cdd4e400-af5e-11eb-855d-6af0011d6a05.png)

### Payload

```json
{
  "device": "[your_device_name]",
  "action": "locked"
}
```

### Example of automation based on webhook

```yaml
- id: my_automation_id
  alias: "My webhook automation"
  trigger:
    platform: webhook
    webhook_id: device_lock
  condition:
    - condition: template
      value_template: "{{ trigger.json.device == '[your_device_name]' and trigger.json.action == 'locked' }}"
  action:
    - service: switch.turn_off
      data:
        entity_id: switch.desk_light
```
