#!/usr/bin/perl

use strict;

my $VYATTA_CONFIG_DIR = "/opt/vyatta/etc/config-migrate";
my $CURRENT_VERSION_DIR = "$VYATTA_CONFIG_DIR/current";

# get the current config version of each "module"
if ((! -d $CURRENT_VERSION_DIR) || !opendir(CUR, "$CURRENT_VERSION_DIR")) {
  print "\n";
  exit 0;
}
my $version_str = "";
foreach (readdir CUR) {
  if (m/^([-\w]+)@(\d+)$/) {
    if ($version_str ne "") {
      $version_str .= ":";
    }
    $version_str .= ("$1" . "@" . "$2");
  }
}
closedir CUR;

print "\n\n/* Warning: Do not remove the following line. */\n";
print "/* === vyatta-config-version: \"$version_str\" === */\n";

exit 0;
