#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
#use Test::More tests => 1;
use Test::Differences;

use List::MoreUtils 'any';

my $HOSTNAME_CMD = 'hostname';
my $IFCONFIG     = '/sbin/ifconfig';

exit main();

sub main {
	my $hostname_short = `$HOSTNAME_CMD --short`;
	$hostname_short    =~ s/^\s*(.*)\s*$/$1/;
	my $hostname_fqdn  = `$HOSTNAME_CMD --fqdn`;
	$hostname_fqdn     =~ s/^\s*(.*)\s*$/$1/;
	
	# short hostname from fqdn
	my ($short) = split /\./, $hostname_fqdn; 
	
	is($short, $hostname_short, 'check short hostname');
	
TODO: {
	local $TODO = 'fix resolv()';
	# resolv ip-s for short and fqdn hostname
	my $hostname_short_ip = resolv($hostname_short);
	my $hostname_fqdn_ip  = resolv($hostname_fqdn);
	is(
		$hostname_short_ip,
		$hostname_fqdn_ip,
		'ip-s of short hostname and fqdn should be the same - '.$hostname_fqdn_ip,
	);

	my %if_named = %{get_ifnames_with_ip()};
	foreach my $ifname (keys %if_named) {
		my $iface = $if_named{$ifname};
		
		$iface->{'hostname'} = resolv($iface->{'ip'});
	}
	
	ok(
		(any { $_->{'ip'} eq $hostname_fqdn_ip } values %if_named ),
		'there should be at leas one interface with hostname ip - '.$hostname_fqdn_ip,
	);
	
	eq_or_diff(
		[ map { $_->{'hostname'} ? $_->{'ip'} : '' } values %if_named ],
		[ map { $_->{'ip'} } values %if_named ],
		'every interface ip should have an revers dns',	
	);
}
	
	
	return 0;
}


sub resolv {
	my $name = shift;
	
}

=head2 get_ifnames_with_ip()

returns hash ref with:

	{
		'lo'   => { 'ip' => '127.0.0.1'     },
		'eth0' => { 'ip' => '192.168.100.6' },
	};


=cut

sub get_ifnames_with_ip {
	my @ifconfig_out = `$IFCONFIG`;
	my %if_named;
	
	my $ifname;
	my $ifip;
	foreach my $line (@ifconfig_out) {
		# empty line resets the values
		if ($line =~ /^\s*$/) {
			$ifname = undef;
			$ifip   = undef;
		}

		# get columns 1, 2, 3
		my ($c1,$c2,$c3) = split /\s+/, $line;

		# get interface name
		$ifname = $c1
			if $c2 eq 'Link';
		# get ip address
		($ifip) = $c3 =~ m/addr:(.+)/
			if $c2 eq 'inet';
		
		# if we have both ip and interface name store it
		$if_named{$ifname} = { 'ip' => $ifip }
			if ($ifname and $ifip);
	}
	
	return \%if_named;
}


