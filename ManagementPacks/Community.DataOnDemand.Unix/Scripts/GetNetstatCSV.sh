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
    awk -v ORS="$lineEnd" -v OFS=',' '{
        gsub(/:/, ",")
        split($7,pid, "/")
        split($5, remote, ",")
        "ps -o args= --pid " pid[1] | getline args
        sub(/^[^"].+[^"]$/, "\"&amp;\"", args)
        "ps -o comm= --pid " pid[1] | getline comm
        print "'"$localHostName"'", pid[1], comm, args, toupper($1), $4, $5, $6, remote[1]
    }'

exit
