#!/usr/bin/perl
#proxy.pl
#© Catholic Education Canberra Goulburn 2013
#Author: Ben Formosa
#
#Dynamically create proxy autoconfiguration files depending on the remote host
#expects the following files:
#pac/header.pac:        function definition for FindProxyForURL, define proxy servers
#pac/rules.pac:         main list of rules. Most should return proxy
#subnets/default:       define the variable proxy and a line with the catch all subnet:
#   proxy = "PROXY host1:8080; PROXY host2:3128";
#   proxy = "PROXY host2:3128; PROXY host1:8080";
#   0.0.0.0/0
#
#To define a different proxy server for a group of IP ranges, create a file in the directory subnets with one or more lines of JavaScript defining proxy, as in subnets/default. Specify the IP ranges in CIDR format, one to each line.
#lines that don't match the CIDR format or match the pattern /^proxy/ will be ignored
#subnets/guest:
#   proxy = "PROXY host:port";
#   #wired
#   192.168.0.0/24
#   #wireless
#   192.168.1.0/24
#
#To define additional rules for a group, create a file with those rules in the pac/ directory, named the same as the file above, but with the extension .pac. 
#pac/guest.pac:
#   if (shExpMatch(url, "example1.com")) return "DIRECT";
#   if (shExpMatch(url, "example2.com")) return proxy;
#
#The most specific subnet defined will be used. 
#Say you define two groups; A and B with the subnets 10.0.0.0/8 and 10.10.10.0/24 respectively.
#The IP address 10.10.10.1 will be treated only as part of group B.
#
#If you define a subnet more than once, there's no guarantee which group they will be a part of.

use strict;
use warnings;
use CGI;
use Net::Subnet;

#pattern to match IPv4 CIDR ranges
my $cidr = '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/(\d|[1-2]\d|3[0-2]))$';

#print a whole file
sub printfile($) {
    open FILE, $_[0] or die $!;
    print <FILE>;
    close FILE or die $!;
}

#create a hash of arrays from an array of input files
#keys are subnets, values are an array: [0] = filename, [1] = array of proxy lines;
sub nethash_fromfiles(@) {
    my @files = @_;
    my @proxies = ();
    my @nets = ();
    my %hash = ();

    foreach my $file (@files) {
        open FILE, $file or die $!;
        my @f = <FILE>;
        close FILE or die $!;

        #create arrays of proxies and subnets from each file
        @proxies = grep /^proxy/, @f;
        @nets = grep /$cidr/, @f;

        #create a hash, with each value of @nets as keys, and an array, $file, @proxies, as the value for each key
        my %temp = map {$_ => [$file, @proxies]} @nets;
        %hash = (%hash, %temp);
    }
    return %hash;
}
sub main() {
    my $cgi = new CGI;
    print $cgi->header( -type => 'application/x-ns-proxy-autoconfig' );
    &printfile("pac/header.pac");

    #name of the subnet group
    my $pac;
    #array of proxies to choose from
    my @proxy = ();
    my $remoteip = $cgi->remote_addr();

    print "//client IP: " . $remoteip . "\n";

    my @files = <subnets/*>;
    my %hash = nethash_fromfiles(@files);

#iterate over the hash, and set @proxy and $pac to values matching the client's IP
    my @nets = keys %hash;
    @nets = sort_subnets @nets;
    foreach my $subnet (@nets) {
        if ((subnet_matcher $subnet)->($remoteip)) {
            $pac = @{$hash{$subnet}}[0];
            @proxy = @{$hash{$subnet}}[1];
            last;
        }
    }

#find the last octet of the remote IP address
    my @octets = split(/\./, $remoteip);
    my $octet = $octets[-1];

#print a proxy. this will give the same proxy for each client unless the number of proxies are changed
    print @proxy[($octet % scalar @proxy)];

    #print the custom rules for the group
    $pac = (split '/', $pac) [-1];
    $pac = "pac/" . $pac . ".pac";
    if(-e $pac) {
        print "//client matches rule: " . $pac . "\n";
        &printfile($pac);
    }

    &printfile("pac/rules.pac");
}

&main;
