#!/bin/sh
# Provides netstat information in a format expected by Squared Up's Visual Application Discovery and Analysis feature.
# Copyright 2018 Squared Up Limited, All Rights Reserved.
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

elevate=""
if [ "$(id -u)" != "0" ]; then
    # Not currently running as root, attempt to elevate
    elevate="sudo"
fi

# Store AWK script 
awkScript='{
        # Local Endpoint Address / Port split
        localEpSplit = match($4, ":[0-9]+$")
        localAddr = substr($4, 0, localEpSplit - 1)
        localPort = substr($4, localEpSplit + 1)

        # Remote Endpoint Address / Port split
        remoteEpSplit = match($5, ":[0-9]+$")
        remoteAddr = substr($5, 0, remoteEpSplit - 1)
        remotePort = substr($5, remoteEpSplit + 1)

        # Extract PID
        split($7,pid, "/")

        if (pid[1] == "-" || pid[1] == "")
        {
            comm = "Unknown"
            args = ""
            pid[1] = -1

        }
        else
        {
            # Query for command (with args) that started the process
            argQuery = elevate " ps -o args= --pid " pid[1] " | cut -c-" processDescMaxLength
            argQuery | getline args
            close(argQuery)

            # Append "..." if the string is max length and does not already end with those characters
            # Avoid using ampersands here to deal with reported encoding differences in some versions of SCOM 2012 and 2016
            if (length(args) == processDescMaxLength) 
            {
                if (substr(args,length(args)-2,3) != "...")
                {
                    args = args "..."
                }
            }   
            
            # Escape double quotes, then Wrap the description in double quotes for CSV
            gsub(/"/, "\"\"", args)
            args = "\"" args "\""
            
            # Query for the process name
            commandQuery = elevate " ps -o comm= --pid " pid[1]
            commandQuery | getline comm
            close(commandQuery)
        }

        # Finally, print records
        print "'"$localHostName"'", pid[1], comm, args, toupper($1), localAddr, localPort, remoteAddr, remotePort, $6, remoteAddr
}'

# Print Header, required by SQUP provider
header="Computername,PID,ProcessName,ProcessDescription,Protocol,LocalAddress,LocalPort,RemoteAddress,RemotePort,State,RemoteAddressIP"
if [ "$lineEnd" = "\n" ]; then
    echo "$header"
else
    echo -n "$header$lineEnd"
fi

# Output netstat info in required format.  -tpn gives us TCP only connections, without host/port lookup, and includes PIDs
if [ "$elevate" != "sudo" ]; then
    netstat -tpn |
        grep ESTABLISHED |
            awk -v ORS="$lineEnd" -v OFS=',' -v processDescMaxLength=$processDescMaxLength -v elevate="$elevate" "$awkScript"
else
    sudo netstat -tpn |
        grep ESTABLISHED |
            awk -v ORS="$lineEnd" -v OFS=',' -v processDescMaxLength=$processDescMaxLength -v elevate="$elevate" "$awkScript"
fi

exit
