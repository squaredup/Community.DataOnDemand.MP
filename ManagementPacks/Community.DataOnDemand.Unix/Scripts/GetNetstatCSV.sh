#!/bin/sh
# Provides netstat information in a format expected by Squared Up's Visual Application Discovery and Analysis feature.
# Copyright 2016 Squared Up Limited, All Rights Reserved.
# Argument Block
# Arg 1 = Format
Format="$1"
if [ -z "$Format" ]; then
    Format="csv"
fi

# Store hostname in case it's not availible in certain shells
localHostName=$(hostname)
processDescMaxLength=128

lineEnd=""
case "$Format" in
    csv)
        lineEnd="\n"
    ;;
    csvEx)
        lineEnd="%EOL%"
    ;;
    *)
        echo "Unknown format type $Format"
        exit 1
    ;;
esac

# Print Header, required by SQUP provider
echo -n "Computername,PID,ProcessName,ProcessDescription,Protocol,LocalAddress,LocalPort,RemoteAddress,RemotePort,State,RemoteAddressIP$lineEnd"

# Output netstat info in required format.  -tpn gives us TCP only connections, without host/port lookup, and includes PIDs
netstat -tpn |
    grep ESTABLISHED |    
    awk -v ORS="$lineEnd" -v OFS=',' -v processDescMaxLength=$processDescMaxLength '{
        # Convert : into , globally, which will give us the port columns from the output naturally.
        gsub(/:/, ",")

        # Extract PID and remote endpoint
        split($7,pid, "/")
        split($5, remote, ",")
        
        # Query for command (with args) that started the process
        argQuery = "ps -o args= --pid " pid[1] " | cut -c-" processDescMaxLength
        argQuery | getline args
        close(argQuery)

        # Append "..." if the string is max length and does not already end with those characters
        if (length(args) == processDescMaxLength &amp;&amp; substr(args,length(args)-2,3) != "...")
            args = args "..."
        
        # Escape double quotes, then Wrap the description in double quotes for CSV
        gsub(/"/, "\"\"", args)
        sub(/^[^"].+[^"]$/, "\"&amp;\"", args)
        
        # Query for the process name
        commandQuery = "ps -o comm= --pid " pid[1]
        commandQuery | getline comm
        close(commandQuery)

        # Finally, print records
        print "'"$localHostName"'", pid[1], comm, args, toupper($1), $4, $5, $6, remote[1]
    }'

exit
