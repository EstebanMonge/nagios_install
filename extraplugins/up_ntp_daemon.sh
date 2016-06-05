#!/usr/bin/expect -f

set password "manager"

spawn su root -c "/etc/init.d/ntp start"
expect "*?assword:*"
send -- "$password\r"
interact

#.EOF
