#!/usr/bin/perl

use strict;
use lib "/opt/vyatta/share/perl5/";
use NetAddr::IP;  # This library is available via libnetaddr-ip-perl.deb
use XorpConfigParser;


use Getopt::Long;
my $input;
my $output;
my $action;
GetOptions("input=s" => \$input, "output=s" => \$output, "action=s" => \$action);

my $xcp = new XorpConfigParser();

if ($action eq 'migrate_service_dhcp_relay_0_to_1') {
	migrate_service_dhcp_relay_0_to_1($input);
} elsif ($action eq 'migrate_service_dhcp_relay_1_to_0') {
	migrate_service_dhcp_relay_1_to_0($input);

} elsif ($action eq 'migrate_service_dhcp_server_0_to_1') {
	migrate_service_dhcp_server_0_to_1($input);
} elsif ($action eq 'migrate_service_dhcp_server_1_to_0') {
	migrate_service_dhcp_server_1_to_0($input);
} elsif ($action eq 'migrate_service_dhcp_server_1_to_2') {
	migrate_service_dhcp_server_1_to_2($input);
} elsif ($action eq 'migrate_service_dhcp_server_2_to_1') {
	migrate_service_dhcp_server_2_to_1($input);

} elsif ($action eq 'migrate_service_webgui_0_to_1') {
	migrate_service_webgui_0_to_1($input);
} elsif ($action eq 'migrate_service_webgui_1_to_0') {
	migrate_service_webgui_1_to_0($input);
}

my $OUTFILE;
if ($output ne '') {
        open $OUTFILE, ">$output";
        select $OUTFILE;
}

$xcp->output(0);


sub migrate_service_dhcp_relay_0_to_1 {
	my ($file) = @_;
	$xcp->parse($file);

	my $hashService = $xcp->get_node(['service']);
	my $hashServiceChildren = $hashService->{'children'};

	my $hashServiceDhcpRelay = $xcp->get_node(['service', 'dhcp', 'relay']);
	if (defined($hashServiceDhcpRelay)) {
		my $childrenServiceDhcpRelay = $hashServiceDhcpRelay->{'children'};
		my @multis = $xcp->copy_multis($childrenServiceDhcpRelay, 'interface');
		foreach my $multiServiceDhcpRelayInterface (@multis) {
			my $childrenInterface = $multiServiceDhcpRelayInterface->{'children'};


			my @childrenDhcpRelay;
			my %hashDhcpRelay = (
				'name' => 'dhcp-relay',
				'children' => \@childrenDhcpRelay
			);
			my %hashDhcpRelayInterface = (
				'name' => 'interface ' . $multiServiceDhcpRelayInterface->{'name'}
			);
			push(@childrenDhcpRelay, \%hashDhcpRelayInterface);

			$xcp->copy_node($childrenInterface, \@childrenDhcpRelay, 'server');
			$xcp->copy_node($childrenInterface, \@childrenDhcpRelay, 'relay-options');

			push(@$hashServiceChildren, \%hashDhcpRelay);
			
		}
	}

	$xcp->comment_out_child($hashServiceChildren, 'dhcp');
}
sub migrate_service_dhcp_relay_1_to_0 {
	my ($file) = @_;
	$xcp->parse($file);

	my $hashService = $xcp->get_node(['service']);
	my $hashServiceChildren = $hashService->{'children'};

	my @pathServiceDhcp_Relay = ('service', 'dhcp', 'relay');
	$xcp->set_value(\@pathServiceDhcp_Relay, '');
	my $hashServiceDhcp_Relay = $xcp->get_node(['service', 'dhcp', 'relay']);
	my $childrenServiceDhcp_Relay = $hashServiceDhcp_Relay->{'children'};
	if (!defined($childrenServiceDhcp_Relay)) {
		my @childrenServiceDhcp_Relay;
		$hashServiceDhcp_Relay->{'children'} = \@childrenServiceDhcp_Relay;
		$childrenServiceDhcp_Relay = \@childrenServiceDhcp_Relay;
	}

	my $hashServiceDhcpRelay = $xcp->get_node(['service', 'dhcp-relay']);
	if (defined($hashServiceDhcpRelay)) {
		my $childrenServiceDhcpRelay = $hashServiceDhcpRelay->{'children'};
		my @multis = $xcp->copy_multis($childrenServiceDhcpRelay, 'interface');
		foreach my $multiServiceDhcpRelayInterface (@multis) {
			my $childrenInterface = $multiServiceDhcpRelayInterface->{'children'};

			my @childrenDhcpRelay;
			my %hashDhcpRelay = (
				'name' => 'relay',
				'children' => \@childrenDhcpRelay
			);

			my @childrenDhcpRelayInterface;
			my %hashDhcpRelayInterface = (
				'name' => 'interface ' . $multiServiceDhcpRelayInterface->{'name'},
				'children' => \@childrenDhcpRelayInterface
			);

			push(@$childrenServiceDhcp_Relay, \%hashDhcpRelayInterface);

			$xcp->copy_node($childrenServiceDhcpRelay, \@childrenDhcpRelayInterface, 'server');
			$xcp->copy_node($childrenServiceDhcpRelay, \@childrenDhcpRelayInterface, 'relay-options');
		}
	}

	$xcp->comment_out_child($hashServiceChildren, 'dhcp-relay');
}
sub migrate_service_dhcp_server_1_to_0 {
	my ($file) = @_;
	$xcp->parse($file);

	my $hashServiceDhcpServer = $xcp->get_node(['service', 'dhcp-server']);
	if (defined($hashServiceDhcpServer)) {
		my $childrenServiceDhcpServer = $hashServiceDhcpServer->{'children'};
		if (defined($childrenServiceDhcpServer)) {
			my @multis = $xcp->copy_multis($childrenServiceDhcpServer, 'shared-network-name');
			foreach my $multi (@multis) {
				my $childrenSharedNetworkName = $multi->{'children'};
				foreach my $childSharedNetworkName (@$childrenSharedNetworkName) {
					my $childSharedNetworkNameNetwork = $childSharedNetworkName->{'name'};

					$childSharedNetworkNameNetwork =~ /(\S*)\/(\d*)/;
					my $subnet = $1;
					my $prefix_length = $2;

					my $nodeInterfaces = $xcp->get_node(['interfaces']);
					if (defined($nodeInterfaces)) {
						my @multisInterfacesEthernet = $xcp->copy_multis($nodeInterfaces->{'children'}, 'ethernet');
						foreach my $multiInterfacesEthernet (@multisInterfacesEthernet) {
							my @multisInterfacesEthernetAddress = $xcp->copy_multis($multiInterfacesEthernet->{'children'}, 'address');
							foreach my $multiInterfacesEthernetAddress (@multisInterfacesEthernetAddress) {
								my $nodeInterfacesEthernetAddressPrefixLength = $xcp->find_child($multiInterfacesEthernetAddress->{'children'}, 'prefix-length');
								if (defined($nodeInterfacesEthernetAddressPrefixLength)) {

									my $prefix_lengthHere = $nodeInterfacesEthernetAddressPrefixLength->{'value'};
									if ($prefix_length == $prefix_lengthHere) {
										my $naip1 = new NetAddr::IP($multiInterfacesEthernetAddress->{'name'} . "/$prefix_length");
										my $subnetHere = $naip1->network()->addr();
										if ($subnet eq $subnetHere) {

											my @childrenServiceDhcpServerName;
											my %hashServiceDhcpServerName = (
												'name' => 'name ' . $multi->{'name'},
												'children' => \@childrenServiceDhcpServerName
											);
											my %hashServiceDhcpServerNameInterface = (
												'name' => 'interface',
												'value'=> $multiInterfacesEthernet->{'name'}
											);
											my %hashServiceDhcpServerNameNetworkMask = (
												'name' => 'network-mask',
												'value' => $prefix_length
											);


											push(@childrenServiceDhcpServerName, \%hashServiceDhcpServerNameInterface);
											push(@childrenServiceDhcpServerName, \%hashServiceDhcpServerNameNetworkMask);

											push(@$childrenServiceDhcpServer, \%hashServiceDhcpServerName);
											$xcp->copy_node($childSharedNetworkName->{'children'}, \@childrenServiceDhcpServerName, 'start');
											$xcp->copy_node($childSharedNetworkName->{'children'}, \@childrenServiceDhcpServerName, 'exclude');
											$xcp->copy_node($childSharedNetworkName->{'children'}, \@childrenServiceDhcpServerName, 'static-mapping');
											$xcp->copy_node($childSharedNetworkName->{'children'}, \@childrenServiceDhcpServerName, 'dns-server');
											$xcp->copy_node($childSharedNetworkName->{'children'}, \@childrenServiceDhcpServerName, 'default-router');
											$xcp->copy_node($childSharedNetworkName->{'children'}, \@childrenServiceDhcpServerName, 'wins-server');
											$xcp->copy_node($childSharedNetworkName->{'children'}, \@childrenServiceDhcpServerName, 'lease');
											$xcp->copy_node($childSharedNetworkName->{'children'}, \@childrenServiceDhcpServerName, 'domain-name');
											$xcp->copy_node($childSharedNetworkName->{'children'}, \@childrenServiceDhcpServerName, 'authoritative');
										}
									}
								}
							}
						}
					}
				}
				$xcp->comment_out_child($childrenServiceDhcpServer, "shared-network-name $multi->{'name'}");
			}
		}
	}
}

sub migrate_service_dhcp_server_0_to_1 {
	my ($file) = @_;
	$xcp->parse($file);

	my $hashServiceDhcpServer = $xcp->get_node(['service', 'dhcp-server']);
	if (defined($hashServiceDhcpServer)) {
		my $childrenServiceDhcpServer = $hashServiceDhcpServer->{'children'};
		if (defined($childrenServiceDhcpServer)) {
			my @multis = $xcp->copy_multis($childrenServiceDhcpServer, 'name');
			foreach my $multi (@multis) {

				my $nodeServiceDhcpServerNameInterface = $xcp->find_child($multi->{'children'}, 'interface');
				my $nodeServiceDhcpServerNameNetworkMask = $xcp->find_child($multi->{'children'}, 'network-mask');

				my @multisServiceDhcpServerNameStart = $xcp->copy_multis($multi->{'children'}, 'start');
				if (@multisServiceDhcpServerNameStart > 0) {
					my $multiServiceDhcpServerNameStart = $multisServiceDhcpServerNameStart[0];
					if (defined($nodeServiceDhcpServerNameInterface) && defined($nodeServiceDhcpServerNameNetworkMask) && defined($multiServiceDhcpServerNameStart)) {
						my $stringInterface = $nodeServiceDhcpServerNameInterface->{'value'};
						my $stringNetworkMask = $nodeServiceDhcpServerNameNetworkMask->{'value'};
						my $stringStart = $multiServiceDhcpServerNameStart->{'name'};
						if ($stringInterface ne '' && $stringNetworkMask ne '' && $stringStart ne '') {
							$stringInterface =~ s/"//g;
							$stringNetworkMask =~ s/"//g;
							my $nodeInterfacesEthernet = $xcp->get_node(['interfaces', "ethernet $stringInterface"]);
							if (defined($nodeInterfacesEthernet)) {
								my @multisInterfacesEthernet = $xcp->copy_multis($nodeInterfacesEthernet->{'children'}, 'address');
								foreach my $multiInterfacesEthernetAddress (@multisInterfacesEthernet) {
									my $stringAddress = $multiInterfacesEthernetAddress->{'name'};
									my $nodeInterfacesEthernetAddressPrefixLength = $xcp->find_child($multiInterfacesEthernetAddress->{'children'}, 'prefix-length');
									if (defined($nodeInterfacesEthernetAddressPrefixLength)) {
										my $stringPrefixLength = $nodeInterfacesEthernetAddressPrefixLength->{'value'};
										if ($stringAddress ne '' && $stringPrefixLength ne '') {
											my $naipInterfaceAddress = new NetAddr::IP("$stringAddress/$stringPrefixLength");
											my $stringInterfaceSubnet = $naipInterfaceAddress->network()->addr();
											my $naipInterfaceSubnet = new NetAddr::IP("$stringInterfaceSubnet/$stringPrefixLength");

											my $naipDHCPStart = new NetAddr::IP("$stringStart/$stringNetworkMask");
											my $stringDHCPSubnet = $naipDHCPStart->network()->addr();
											my $naipDHCPSubnet = new NetAddr::IP("$stringDHCPSubnet/$stringNetworkMask");

											if ($naipDHCPSubnet->within($naipInterfaceSubnet)) {

												my @childrenServiceDhcpServerSharedNetworkName;
												my %hashServiceDhcpServerSharedNetworkName = (
													'name' => 'shared-network-name ' . $multi->{'name'},
													'comment' => $multi->{'comment'},
													'value' => $multi->{'value'},
													'children' => \@childrenServiceDhcpServerSharedNetworkName
												);


												my @childrenServiceDhcpServerSharedNetworkNameSubnet;
												my %hashServiceDhcpServerSharedNetworkNameSubnet = (
													'name' => "subnet " . $naipDHCPSubnet->network()->addr() . '/' . $stringNetworkMask,
													'children' => \@childrenServiceDhcpServerSharedNetworkNameSubnet
												);
												push(@childrenServiceDhcpServerSharedNetworkName, \%hashServiceDhcpServerSharedNetworkNameSubnet);
												$xcp->copy_node($multi->{'children'}, \@childrenServiceDhcpServerSharedNetworkNameSubnet, 'start');
												$xcp->copy_node($multi->{'children'}, \@childrenServiceDhcpServerSharedNetworkNameSubnet, 'exclude');
												$xcp->copy_node($multi->{'children'}, \@childrenServiceDhcpServerSharedNetworkNameSubnet, 'static-mapping');
												$xcp->copy_node($multi->{'children'}, \@childrenServiceDhcpServerSharedNetworkNameSubnet, 'dns-server');
												$xcp->copy_node($multi->{'children'}, \@childrenServiceDhcpServerSharedNetworkNameSubnet, 'default-router');
												$xcp->copy_node($multi->{'children'}, \@childrenServiceDhcpServerSharedNetworkNameSubnet, 'wins-server');
												$xcp->copy_node($multi->{'children'}, \@childrenServiceDhcpServerSharedNetworkNameSubnet, 'lease');
												$xcp->copy_node($multi->{'children'}, \@childrenServiceDhcpServerSharedNetworkNameSubnet, 'domain-name');
												$xcp->copy_node($multi->{'children'}, \@childrenServiceDhcpServerSharedNetworkNameSubnet, 'authoritative');

												push(@$childrenServiceDhcpServer, \%hashServiceDhcpServerSharedNetworkName);
											}
										}
									}
								}
							}
						}
					}
				}
				$xcp->comment_out_child($childrenServiceDhcpServer, "name $multi->{'name'}");
			}
		}
	}
}

# do nothing as the current version for dhcp-server in glendale was still 1 
# the version was not changed to 2 in glendale and so the code for migration never got executed
# also, 'exclude' should have been removed from cli but was still on glendale, however, did nothing
# code to comment out exclude has been removed now when upgrading to version 2
# dhcp-server in glendale (still version 1) will get upgraded to version 2 
# which does nothing and then 2 to hollywood (version 3) on upgrade from glendale to hollywood 
sub migrate_service_dhcp_server_1_to_2 {
	my ($file) = @_;
	$xcp->parse($file);

}

# This migration involves no changes to the configuration.
sub migrate_service_dhcp_server_2_to_1 {
	my ($file) = @_;
	$xcp->parse($file);
}

sub migrate_service_webgui_0_to_1 {
	my ($file) = @_;
	$xcp->parse($file);

	my $hashService = $xcp->get_node(['service']);
	my $hashServiceChildren = $hashService->{'children'};

	my $hashServiceHttp = $xcp->get_node(['service', 'http']);
	if (defined($hashServiceHttp)) {
		my $http_port;
		my $hashServiceHttpPort = $xcp->find_child($hashServiceHttp->{'children'}, 'port');
		if (defined($hashServiceHttpPort)) {
			$http_port = $hashServiceHttpPort->{'value'};
		}

		my @childrenServiceWebgui;
		my %hashServiceWebgui = (
			'name' => 'webgui',
			'children' => \@childrenServiceWebgui
		);
		if (defined($http_port)) {
			my %hashServiceWebguiHttpPort = (
				'name' => 'http-port',
				'value' => $http_port
			);
			push(@childrenServiceWebgui, \%hashServiceWebguiHttpPort);
		}
		push(@$hashServiceChildren, \%hashServiceWebgui);
	}
	$xcp->comment_out_child($hashServiceChildren, 'http');
}

sub migrate_service_webgui_1_to_0 {
	my ($file) = @_;
	$xcp->parse($file);

	my $hashService = $xcp->get_node(['service']);
	my $hashServiceChildren = $hashService->{'children'};

	my $hashServiceWebgui = $xcp->get_node(['service', 'webgui']);
	if (defined($hashServiceWebgui)) {
		my $http_port;
		my $hashServiceWebguiHttpPort = $xcp->find_child($hashServiceWebgui->{'children'}, 'http-port');
		if (defined($hashServiceWebguiHttpPort)) {
			$http_port = $hashServiceWebguiHttpPort->{'value'};
		}

		my @childrenServiceHttp;
		my %hashServiceHttp = (
			'name' => 'http',
			'children' => \@childrenServiceHttp
		);
		if (defined($http_port)) {
			my %hashServiceHttpPort = (
				'name' => 'port',
				'value' => $http_port
			);
			push(@childrenServiceHttp, \%hashServiceHttpPort);
		}
		push(@$hashServiceChildren, \%hashServiceHttp);
	}
	$xcp->comment_out_child($hashServiceChildren, 'webgui');
}


