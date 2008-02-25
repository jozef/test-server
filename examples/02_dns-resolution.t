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
	        thirdone.com:
	            A: 192.168.100.5
	            CNAME: dan-ip2.ant.local
	__YAML_END__

=cut

use strict;
use warnings;

use Test::More;
#use Test::More tests => 1;
use Test::Differences;
use Test::Exception;
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
	
	foreach my $domain (keys %$domains) {
		my $query = $res->search($domain);
		ok($query, 'lookup '.$domain) or next;
		
		my $expected_rrs = $domains->{$domain};
		next if not defined $expected_rrs;
		
		while (my ($rr_type, $rr_value) = each %{$expected_rrs}) {
			is_deeply(
				[ $query->answer_rr_with_type($rr_type) ],
				[ $rr_value ],
				'check dns '.$rr_type.' answer',
			);
		}
	}
	
	return 0;
}


sub Net::DNS::Packet::answer_rr_with_type {
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
	
	return @rrs_answer;
}
