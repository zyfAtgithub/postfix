#!/usr/bin/expect
spawn mysql -u root -p
expect "password:"
send "\r\n"
send "GRANT ALL ON extmail.* to extmail@'%' identified by 'extmail';\r\n"
send "FLUSH PRIVILEGES;\r\n"
send "exit;\r\n"
expect "Bye"
interact