---
description: Increase VPS SSH timeouts for better connection stability
---
Check current SSH settings:
!`grep -i clientalive /etc/ssh/sshd_config || echo 'No ClientAlive settings found'`

Apply new settings to increase timeout to 10 minutes:
!`echo 'ClientAliveInterval 60' | sudo tee -a /etc/ssh/sshd_config`
!`echo 'ClientAliveCountMax 10' | sudo tee -a /etc/ssh/sshd_config`

Restart SSH service:
!`sudo systemctl restart sshd`

Verify the settings:
!`grep -i clientalive /etc/ssh/sshd_config`

Done! SSH timeout increased to 10 minutes.