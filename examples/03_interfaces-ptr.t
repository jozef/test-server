#!/usr/bin/perl

=head1 NAME

interfaces-ptr.t - check if interfaces has a PTR record which properly resolves back to interface ip

=head SYNOPSIS

	cat >> test-server.yaml << __YAML_END__
	interfaces-ptr:
	    ignore:
	        - tap9
	        - br0
	        - "br1:"
	__YAML_END__

=cut

use strict;
use warnings;

use Test::More;
#use Test::More tests => 1;
use Test::Differences;
use YAML::Syck 'LoadFile';
use FindBin '$Bin';
use List::MoreUtils 'any';
use Sys::Net;

eval "use Net::DNS::Resolver";
plan 'skip_all' => "need Net::DNS::Resolver to run dns tests" if $@;

my $config = LoadFile($Bin.'/test-server.yaml');


exit main();

sub main {
	my @skip_interfaces = @{$config->{'interfaces-ptr'}->{'ignore'} || []};
	push @skip_interfaces, 'lo';
	
	my $res = Net::DNS::Resolver->new;
	
	# loop through interfaces and check their PTR
	my %if_named = %{Sys::Net->interfaces()};
	
	plan 'tests' => (keys %if_named)*2;
	
	foreach my $if_name (keys %if_named) {
		my ($ptr, $ip, $if_ignored);
		
		SKIP: {
			$if_ignored = any { $if_name =~ m/^$_/; } @skip_interfaces;
			skip 'skipping '.$if_name.' in ignore list ', 2
				if $if_ignored;
			
			# lookup PTR
			$ip  = $if_named{$if_name}->{'ip'};
			my $answer = $res->search($ip);
			
			$ptr = $answer->rr_with_type('PTR')
				if $answer;
			ok($ptr, 'check interface '.$if_name.' ip '.$ip.' to hostname');
		}
		
		# check hostname to interface ip resolving
		if (not $if_ignored) {
			SKIP: {
				skip $if_name.' has no hostname', 1
					if not $ptr;
				
				my $answer = $res->search($ptr);
				my $ip_from_ptr = $answer->rr_with_type('A')
					if $answer;
				is($ip_from_ptr, $ip, 'check if the hostname '.$ptr.' resolv back to original ip '.$ip);
			}
		}
	}
	
	return 0;
}


sub Net::DNS::Packet::rr_with_type {
	my $self    = shift;
	my $rr_type = shift;
	
	my @rrs_answer;
	foreach my $rr ($self->answer) {
		next if $rr->type ne $rr_type;
		
		push @rrs_answer, (
			$rr_type eq 'A'     ? $rr->address  :
			$rr_type eq 'CNAME' ? $rr->cname    :
			$rr_type eq 'PTR'   ? $rr->ptrdname :
			$rr->string,
		);
	}
	
	return (wantarray ? sort @rrs_answer : shift @rrs_answer);
}


__END__

=head1 NOTE

DNS resolution depends on L<Net::DNS::Resolver>.

=head1 AUTHOR

Jozef Kutej

=cut
