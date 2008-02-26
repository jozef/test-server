#!/usr/bin/perl

=head1 NAME

hostname-and-interfaces - check hostname and ip resolution on interfaces

=head2 SYNOPSIS

	NONE

=head2 DESCRIPTION

Checks the hostname short name and fqdn. Cheks the ip adresses on the interfaces
if resolv to some hostname. 

=cut

use strict;
use warnings;

use Test::More 'tests' => 5;
use Test::Differences;

use List::MoreUtils 'any';
use Socket 'inet_ntoa', 'inet_aton', 'AF_INET';

my $HOSTNAME_CMD = 'hostname';
my $IFCONFIG_CMD = '/sbin/ifconfig';

exit main();


sub main {	
	my $hostname_short_ip;
	my $hostname_fqdn_ip;
	SKIP: {
		my $hostname = `$HOSTNAME_CMD`;
		skip 'hostname command not found', 2
			if not defined $hostname;
					
		my $hostname_short = `$HOSTNAME_CMD --short`;
		$hostname_short    =~ s/^\s*(.*)\s*$/$1/;
		diag 'short hostname - ', $hostname_short
			if $ENV{TEST_VERBOSE};
		my $hostname_fqdn  = `$HOSTNAME_CMD --fqdn`;
		$hostname_fqdn     =~ s/^\s*(.*)\s*$/$1/;
		diag 'fqdn hostname  - ', $hostname_fqdn
			if $ENV{TEST_VERBOSE};
		
		isnt($hostname_short, $hostname_fqdn, 'short hostname should not be the same as fqdn');
		
		# short hostname from fqdn
		my ($short) = split /\./, $hostname_fqdn; 
		
		is($short, $hostname_short, 'check short hostname');
		
		# resolv ip-s for short and fqdn hostname
		$hostname_short_ip = resolv($hostname_short);
		$hostname_fqdn_ip  = resolv($hostname_fqdn);
		is(
			$hostname_short_ip,
			$hostname_fqdn_ip,
			'ip-s of short hostname and fqdn should be the same - '.$hostname_fqdn_ip,
		);
	}

	SKIP: {
		skip 'fqdn not found', 2
			if not defined $hostname_fqdn_ip;

		my $ifconfig = `$IFCONFIG_CMD`;
		skip 'ifconfig command not found', 2
			if not defined $ifconfig;
		
		# get interfaces
		my %if_named = %{get_ifnames_with_ip()};

		ok(
			(any { $_->{'ip'} eq $hostname_fqdn_ip } values %if_named ),
			'there should be at leas one interface with hostname ip - '.$hostname_fqdn_ip,
		);
		
		# loop through all interfaces
		foreach my $ifname (keys %if_named) {
			my $iface = $if_named{$ifname};
			
			# resolv interface ip to hostnames
			$iface->{'hostname'} = resolv($iface->{'ip'});
			diag 'if ', $ifname, ' ip ', $iface->{'ip'}, ' resolves to ', $iface->{'hostname'}
				if $ENV{TEST_VERBOSE};
		}
		
		# check if every interface has a hostname set (different from the ip)
		eq_or_diff(
			[ map {
					$_->{'hostname'}
					&& ($_->{'hostname'} ne $_->{'ip'})
					? $_->{'ip'}
					: 'not resolving'
				} values %if_named ],
			[ map { $_->{'ip'} } values %if_named ],
			'every interface ip should resolv to a name',	
		);
	}	
	
	return 0;
}


=head1 INTERNAL METHODS

=head2 resolv()

Resolv hostname to an ip or ip to an hostname.

=cut

sub resolv {
	my $name = shift;
	
	# resolv ip to a hostname
	if ($name =~ m/^\s*[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\s*$/) {
		return scalar gethostbyaddr(inet_aton($name), AF_INET);
	}
	# resolv hostname to ip
	else {
		return inet_ntoa(scalar gethostbyname($name));
	}
}


=head2 get_ifnames_with_ip()

returns hash ref with:

	{
		'lo'   => { 'ip' => '127.0.0.1'     },
		'eth0' => { 'ip' => '192.168.100.6' },
	};


=cut

sub get_ifnames_with_ip {
	my @ifconfig_out = `$IFCONFIG_CMD`;
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

__END__

=head1 NOTE

Not too portable... Runs on linux and should skip the tests on different OSes.

=head1 AUTHOR

Jozef Kutej

=cut
