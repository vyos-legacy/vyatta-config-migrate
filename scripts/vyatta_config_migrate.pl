#!/usr/bin/perl

# Usage: vyatta_config_migrate.pl <config_file>

use strict;
use Sys::Syslog qw(:standard :macros);

my $VYATTA_CONFIG_DIR = "/opt/vyatta/etc/config-migrate";
my $CURRENT_VERSION_DIR = "$VYATTA_CONFIG_DIR/current";
my $MIGRATE_DIR = "$VYATTA_CONFIG_DIR/migrate";

my $DEBUG_LOG = "/var/log/vyatta/migrate.log";
my $dbg = 0;
if ($dbg) {
  open(DBG, ">>$DEBUG_LOG") or $dbg = 0;
}
print DBG "---\n" if ($dbg);
openlog("config-migrate", "", LOG_USER);

# get the config version of each "module" in the config file
my %conf_version = ();
if ($#ARGV != 0) {
  print STDERR "Usage: vyatta_config_migrate.pl <config_file>\n";
  exit 1;
}
my $config_file = $ARGV[0];
if (!open(CONF, "$config_file")) {
  syslog("warning", "Cannot open config file %s. Migration aborted",
         $config_file);
  print DBG "Cannot open config file $config_file. Migration aborted.\n"
    if ($dbg);
  exit 1;
}
my $version_string_present = 0;
while (<CONF>) {
  chomp;
  if (m/=== vyatta-config-version: "(.*?)" ===/) {
    $version_string_present = 1;
    foreach (split /:/, $1) {
      my ($mod, $ver) = split /@/;
      $conf_version{$mod} = $ver;
    }
    last;
  }
}
close CONF;
my $backup_file = $config_file . "." . `date +%F-%H%M`;
chomp $backup_file;
$backup_file .= '.pre-migration';

# get the current config version of each "module"
my %cur_version = ();
if ((! -d $CURRENT_VERSION_DIR) || !opendir(CUR, "$CURRENT_VERSION_DIR")) {
  syslog("info", "No migration needed");
  print DBG "Cannot open version directory $CURRENT_VERSION_DIR. "
            . "No migration needed.\n" if ($dbg);
  exit 0;
}
foreach (readdir CUR) {
  if (m/^([-\w]+)@(\d+)$/) {
    $cur_version{$1} = $2;
  }
}
closedir CUR;

foreach (keys %conf_version) {
  if (!defined($cur_version{$_})) {
    $cur_version{$_} = 0;
  }
}

my $backup = 1;

my $version_str = "";
my $status = 0;
# check if each module needs migration
foreach (sort (keys %cur_version)) {
  my $mod = $_;
  my ($conf_ver, $cur_ver) = (0, $cur_version{$mod});
  if (defined($conf_version{$mod})) {
    $conf_ver = $conf_version{$mod};
  }

  if ($conf_ver != $cur_ver) {
    # migration needed
    if ($backup) {
      # check if the config is writable. abort if not.
      if (! -w $config_file) {
        syslog("warning", "Config file %s is not writable. Migration aborted.",
               $config_file);
        print DBG "Config file $config_file is not writable. "
                  . "Migration aborted.\n" if ($dbg);
        exit 1;
      }
      # back up the original config.
      my $ret = system("cp -f $config_file $backup_file");
      if ($ret >> 8) {
        syslog("warning",
               "Cannot back up the config file. Migration aborted.");
        print DBG "Cannot back up the config file. Migration aborted.\n"
          if ($dbg);
        exit 1;
      }
      $backup = 0;
    }
    # migrate one version at a time
    while ($conf_ver != $cur_ver) {
      my $nxt_ver = ($conf_ver < $cur_ver) ? ($conf_ver + 1) : ($conf_ver - 1);
      print DBG "$mod: $conf_ver -> $nxt_ver\n" if ($dbg);
      my $cmd = "$MIGRATE_DIR/$mod/$conf_ver-to-$nxt_ver";
      my ($ret, $err) = (0, 'Migration script does not exist');
      if (-f $cmd) {
        $ret = system("$cmd $config_file");
        $err = $!;
      } else {
        # script does not exist. not an error (no-op).
        print DBG "Config file migration: module=$mod "
                  . "ver=$conf_ver nxt=$nxt_ver [$err]\n" if ($dbg);
      }
      if ($ret >> 8) {
        # script execution failed
        syslog("warning",
               "Config file migration failed: module=%s ver=%s nxt=%s [%s]",
               $mod, $conf_ver, $nxt_ver, $err);
        print DBG "Config file migration failed: module=$mod "
                  . "ver=$conf_ver nxt=$nxt_ver [$err]\n" if ($dbg);
        # stop processing this module (or should we stop altogether?)
        $status = 1;
        last;
      }
      if ($conf_ver < $cur_ver) {
        $conf_ver++;
      } else {
        $conf_ver--;
      }
    }
  }

  if ($version_str ne "") {
    $version_str .= ":";
  }
  $version_str .= ("$mod" . "@" . "$cur_ver");
}

# add the version string to the file if it's already changed
if (!$backup && !$version_string_present) {
  if (!open(CONF, ">>$config_file")) {
    syslog("warning", "Cannot modify config file %s. Migration aborted.",
           $config_file);
    print DBG "Cannot modify config file $config_file. "
              . "Migration aborted.\n" if ($dbg);
    exit 1;
  }
  print CONF "\n\n/* Warning: Do not remove the following line. */\n";
  print CONF "/* === vyatta-config-version: \"\" === */\n";
  close CONF;
}

# change the version string in the file if it's already changed
if (!$backup) {
  my $cmd = "sed -i 's/\\(=== vyatta-config-version: \"\\).*\\(\" ===\\)/"
            . "\\1$version_str\\2/' $config_file";
  my $ret = system($cmd);
  if ($ret >> 8 == 0) {
    $cmd = '/opt/vyatta/sbin/vyatta_current_conf_ver.pl';
    my @lines = `$cmd | grep '^/\\* Release version:.*\\*/\$'`;
    if ($lines[0]) {
      $cmd = "sed -i '/^\\\/\\* Release version:.*\\*\\\/\$/d' $config_file";
      $ret = system($cmd);
      if ($ret >> 8 == 0) {
        $ret = system("echo '$lines[0]' >>$config_file");
      }
    }
  }
  if ($ret >> 8) {
    syslog("warning", "Cannot modify config file %s. Migration aborted.",
           $config_file);
    print DBG "Cannot modify config file $config_file. "
              . "Migration aborted.\n" if ($dbg);
    exit 1;
  }
}

if ($status == 0) {
  if ($backup) {
    # config not changed
    syslog("info", "No migration needed");
  } else {
    syslog("info", "Config file %s migrated.", $config_file);
  }
}

close DBG if ($dbg);

exit $status;

