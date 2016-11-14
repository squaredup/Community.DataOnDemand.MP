#!/bin/sh
# Provides name/IpAddress information in a format expected by Squared Up's Visual Application Discovery and Analysis feature.
# Copyright 2016 Squared Up Limited, All Rights Reserved.
# Argument Block
# Arg 1 = Format
Format="$1"
if [ -z "$Format" ]; then
    Format="csv"
fi

# Arg 2 = Hostnames or addresses
AddressArg="$2"
if [ -z "$AddressArg" ]; then	
	exit 0
fi