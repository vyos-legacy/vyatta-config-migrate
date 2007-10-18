#!/usr/bin/perl

use strict;


use Getopt::Long;
my $interface;
my $preflen;
GetOptions("interface=s" => \$interface, "preflen" => \$preflen);


use VyattaMisc;
my $vm = new VyattaMisc();

use NetAddr::IP;  # This library is available via libnetaddr-ip-perl.deb
my $naip = $vm->getNetAddrIP($interface);
if (!defined($naip)) {
  print STDERR "Error:  Unable to determine IP subnet / netmask information.\n";
  exit(1);

}

if (defined($preflen)) {
  my $prefix_len = $naip->network()->masklen();
  print "$prefix_len\n";
} else {
  my $subnet = $naip->network()->addr();
  print "$subnet\n";
}


