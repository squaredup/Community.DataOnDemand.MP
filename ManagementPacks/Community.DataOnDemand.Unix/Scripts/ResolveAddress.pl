#!/usr/bin/perl -w
# Provides Provides name/IpAddress information in a format expected by Squared Up's Visual Application Discovery and Analysis feature.
# Copyright 2016 Squared Up Limited, All Rights Reserved.

use strict;
use warnings;
use Socket;

# Handle arguments and global vars
my $format = "csv";
my $lineEnd;
my @queries;

if ( $#ARGV &lt; 0 || $#ARGV &gt; 1 ) {
    print "Usage: $0 [format] nameOrIp\n";
    exit(1);
}
elsif ($#ARGV == 0) {
    @queries = split(/\s*,\s*/, $ARGV[0]);
}
elsif ($#ARGV == 1) {
    $format = $ARGV[0];
    @queries = split(/\s*,\s*/, $ARGV[1]);
}

# Set output format
if ($format eq "csv") {
    $lineEnd = "\n";
}
elsif ($format eq "csvEx") {
    $lineEnd = "\%EOL\%"
}
else {
    print "Unknown format '$format'\n";
    exit(1);
}

# Although Socket could be used instead of regex and manual validation, the behaviour and availability is not platform consistent.
sub _is_ipv4 {
    shift if ref $_[0];
    my $value = shift;

    return undef unless defined($value);

    my (@octets) = $value =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
    return undef unless (@octets == 4);
    foreach (@octets) {
        return undef if $_ &lt; 0 || $_ &gt; 255;
        return undef if $_ =~ /^0\d{1,2}$/;
    }
    return join('.', @octets);
}

# Print Header
print "IpAddress,HostName$lineEnd";

# Process queries based on query type (A or PTR)
foreach my $query (@queries) {
    if (_is_ipv4($query)) {            
        my $hostname = gethostbyaddr(inet_aton($query), AF_INET);
        if ($hostname){
            print "$query,$hostname$lineEnd";
        }    
    }
    else {        
        my @result = gethostbyname($query);
        if (@result) {
            my $ipaddr = inet_ntoa($result[4]);
            print "$ipaddr,$query$lineEnd";
        } 
    }
}

exit(0);
