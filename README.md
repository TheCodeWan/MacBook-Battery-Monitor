# MacBook-Battery-Monitor
This is a script that is designed to run in the background and pull important battery stats from your MacBook, and save them to an iCloud file that updates once a minute. That way, you can check on your Mac battery remotely using any other device that has access to iCloud syncing, including your iPhones. 

All you have to do to start the script is copy the entire raw contents of `macbook_battery_monitor.sh` and paste it into your Terminal, press Enter, possibly put in your password and press Enter again (the script uses some `sudo` commands to get battery data), and then you are good to go! 

You can stop the script at any time by putting in `pkill -f battery_monitor.sh`.