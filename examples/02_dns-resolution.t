#!/usr/bin/perl

=head1 NAME

dns-resolution.t - query dns server and check for the answers

=head SYNOPSIS

	cat >> test-server.yaml << __YAML_END__
	dns-resolution:
	    domains:
	        somedomain.org:
	        someother.com:
	            A: 192.168.100.6
	        thirdomaine.com:
	            A: 192.168.100.5
	            CNAME: ip2-somedomain.com
	__YAML_END__

=cut

use strict;
use warnings;

use Test::More;
#use Test::More tests => 1;
use Test::Differences;
use YAML::Syck 'LoadFile';
use FindBin '$Bin';

eval "use Net::DNS::Resolver";
plan 'skip_all' => "need Net::DNS::Resolver to run dns tests" if $@;

my $config = LoadFile($Bin.'/test-server.yaml');
plan 'skip_all' => "no configuration sections for 'dns-resolution'"
	if (not $config or not $config->{'dns-resolution'});


exit main();

sub main {
	plan 'no_plan';
	
	my $domains = $config->{'dns-resolution'}->{'domains'};
	my $res = Net::DNS::Resolver->new;
	
	# loop through domains that need to be checked
	foreach my $domain (keys %$domains) {
		# lookup domain, if fial skip the rest of the tests for it
		my $answer = $res->search($domain);
		ok($answer, 'lookup '.$domain) or next;
		
		# what rrs need to be tested
		my $expected_rrs = $domains->{$domain};
		next if not defined $expected_rrs;
		
		# loop through the rrs and test them
		while (my ($rr_type, $rr_value) = each %{$expected_rrs}) {
			# make array of the expected value
			my @rr_values = (
				ref $rr_value ne 'ARRAY'
				? $rr_value
				: @$rr_value
			);
			
			eq_or_diff(
				[ $answer->rr_with_type($rr_type) ],
				[ sort @rr_values ],
				'check dns '.$rr_type.' answer for '.$domain,
			);
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
			$rr_type eq 'A'     ? $rr->address :
			$rr_type eq 'CNAME' ? $rr->cname   :
			$rr->string,
		);
	}
	
	return sort @rrs_answer;
}


__END__

=head1 NOTE

DNS resolution depends on L<Net::DNS::Resolver>.

=head1 AUTHOR

Jozef Kutej

=cut
