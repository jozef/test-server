#!/usr/bin/perl

=head1 NAME

net-hops.t - check network hops

=head SYNOPSIS

	cat >> test-server.yaml << __YAML_END__
	net-hops:
		-
			hostname: ba.pm.org
			hops:
				- 10.0.0.138
				- 62.47.95.239
				- 172.19.63.41
		-
			hostname: ba.pm.org
			ttl: 50
			skip: 4
			last-hops:
				- 217.119.114.30
				- 81.89.48.168
				- 81.89.49.242
	__YAML_END__

=cut

use strict;
use warnings;

use Test::More;
#use Test::More tests => 1;
use Test::Differences;
use YAML::Syck 'LoadFile';
use FindBin '$Bin';
use IPC::Run qw( start pump timeout );

my $config = LoadFile($Bin.'/test-server.yaml');


exit main();

sub main {
	my @routes_to_check = @{$config->{'net-hops'} || []};
	
	plan 'skip_all' => "no routes defined" if @routes_to_check == 0;
	plan 'tests' => (scalar @routes_to_check);
	
	foreach my $route (@routes_to_check) {
		SKIP: {
			my $hostname  = $route->{'hostname'};
			my $ttl       = $route->{'ttl'} || 30;
			my $hops      = $route->{'hops'};
			my $last_hops = $route->{'last-hops'};
			my $first_ttl = $route->{'skip'} || 1;
			
			$ttl = scalar(@{$hops})
				if $hops;
			$ttl = 4 if $ttl < 4;
			
			skip 'need hostname parameter to run traceroute', 1
				if not defined $hostname;
			
			my @traceroute_output;
			my ($out, $err);
			my @cmd = ('traceroute', '-q5', '-w15', '-n', '-m'.$ttl, '-f'.$first_ttl, $hostname);
			diag('`'.join(' ', @cmd).'`');
			
			my $traceroute = eval { start \@cmd, \"", \$out, \$err, timeout( 60 ) or die "traceroute exec failed: $?" };
			skip 'failed to execute traceroute program - '.$@, 1
				if not $traceroute;
			
			my @route_hops;
			while (pump $traceroute) {				
				next if index($out, "\n") == -1;
				
				my @lines = split("\n", $out);
				$out = pop @lines;
				
				parse_traceroute_line(\@route_hops, $_)
					foreach (@lines);
			}
			parse_traceroute_line(\@route_hops, $out);
			shift @route_hops;   # [0] index is always empty
						
			if ($hops) {
				@route_hops = splice(@route_hops, 0, scalar @{$hops});
				eq_or_diff(\@route_hops, $hops, 'comparing first '.scalar @{$hops}.' route hops');
			}
			elsif ($last_hops) {				
				@route_hops = splice(@route_hops, -scalar @{$last_hops});
				eq_or_diff(\@route_hops, $last_hops, 'comparing last '.scalar @{$last_hops}.' route hops');
			}
			else {
				skip 'no hops or last_hops defined in config', 1;
			}
		}

	}
	
	return 0;
}

sub parse_traceroute_line {
	my $route = shift;
	my $line  = shift;
	
	if ($line =~ m/^traceroute /) {
	}
	elsif ($line =~ m/
			^
				\s*
				(\d+)
				.*
				\s+
				(\d+[.]\d+[.]\d+[.]\d+)
				(?:\s|$)
			/xms) {
		$route->[$1] = $2
			if $2;
	}
	elsif ($line =~ m/^\s*\d+\s*\s*\s*/) {
	}
	elsif (not $line) {
	}
	else {
		warn 'unrecognized traceroute line: "'.$line.'"';
	}
}

__END__

=head1 NOTE

Depends on C<traceroute> system command.

=head1 AUTHOR

Jozef Kutej

=cut
