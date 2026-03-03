#!/bin/sh
# Provides netstat information in a format expected by Squared Up's Visual Application Discovery and Analysis feature.
# Copyright 2018 Squared Up Limited, All Rights Reserved.

# Improved for performance: caches per-PID lookups; avoids extra processes - 02/24/2026
echo "$(date) - Script executed" >> /tmp/scom_script_debug.log
Format="$1"
if [ -z "$Format" ]; then
Format="csv"
fi

localHostName=$(hostname)
processDescMaxLength=128

case "$Format" in
  csv)   lineEnd="\n" ;;
  csvEx) lineEnd="%EOL%" ;;
  *)
    printf '%s\n' "Unknown format type $Format"
    exit 1
    ;;
esac

# Decide whether we need sudo (and keep it as a string awk can use)
if [ "$(id -u)" -ne 0 ]; then
  elevate="sudo"
else
  elevate=""
fi

header="Computername,PID,ProcessName,ProcessDescription,Protocol,LocalAddress,LocalPort,RemoteAddress,RemotePort,State,RemoteAddressIP"

if [ "$lineEnd" = "\n" ]; then
  printf '%s\n' "$header"
else
  printf '%s' "$header$lineEnd"
fi

# Run netstat once, optionally via sudo
if [ -n "$elevate" ]; then
  NETCMD="sudo netstat -tpn"
else
  NETCMD="netstat -tpn"
fi

# AWK: filter ESTABLISHED in-process; cache per PID; avoid cut/grep
$NETCMD 2>/dev/null | awk \
  -v ORS="$lineEnd" \
  -v OFS=',' \
  -v host="$localHostName" \
  -v processDescMaxLength="$processDescMaxLength" \
  -v elevate="$elevate" '
  # Skip anything that does not look like a TCP line
  $1 !~ /^tcp/ { next }

  # Only ESTABLISHED (netstat state column is usually $6 for -tpn TCP lines)
  $6 != "ESTABLISHED" { next }

  {
    # Local endpoint $4, remote endpoint $5
    localEpSplit  = match($4, ":[0-9]+$")
    remoteEpSplit = match($5, ":[0-9]+$")

    localAddr = (localEpSplit  ? substr($4, 1, localEpSplit - 1)  : $4)
    localPort = (localEpSplit  ? substr($4, localEpSplit + 1)     : "")

    remoteAddr = (remoteEpSplit ? substr($5, 1, remoteEpSplit - 1) : $5)
    remotePort = (remoteEpSplit ? substr($5, remoteEpSplit + 1)    : "")

    # Extract PID from "PID/Program"
    split($7, pidParts, "/")
    pid = pidParts[1]

    if (pid == "-" || pid == "") {
      pid = -1
      comm = "Unknown"
      args = "\"\""
    } else {
      # Cache per PID to avoid running ps repeatedly
      if (!(pid in commCache)) {

        # Process name
        if (elevate != "") cmd = elevate " ps -o comm= --pid " pid
        else               cmd = "ps -o comm= --pid " pid

        cmd | getline comm
        close(cmd)
        if (comm == "") comm = "Unknown"
        commCache[pid] = comm

        # Full args (truncate in awk instead of cut)
        if (elevate != "") cmd2 = elevate " ps -o args= --pid " pid
        else               cmd2 = "ps -o args= --pid " pid

        cmd2 | getline argsRaw
        close(cmd2)
        if (argsRaw == "") argsRaw = ""

        # Truncate
        if (length(argsRaw) > processDescMaxLength) {
          argsRaw = substr(argsRaw, 1, processDescMaxLength)
        }

        # Append "..." if exactly max length and not already ending in it
        if (length(argsRaw) == processDescMaxLength) {
          if (substr(argsRaw, length(argsRaw)-2, 3) != "...") {
            argsRaw = argsRaw "..."
          }
        }

        # CSV escape quotes and wrap
        gsub(/"/, "\"\"", argsRaw)
        argsCache[pid] = "\"" argsRaw "\""
      }

      comm = commCache[pid]
      args = argsCache[pid]
    }

    # Output row
    print host, pid, comm, args, toupper($1), localAddr, localPort, remoteAddr, remotePort, $6, remoteAddr
  }'

exit 0