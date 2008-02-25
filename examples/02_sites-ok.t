#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
#use Test::More tests => 18;
use Test::Differences;
use Test::Exception;
use Test::WWW::Mechanize;

exit main();

sub main {
	my $mech = Test::WWW::Mechanize->new;
	
	my %sites = (
		'http://bratislava.pm.org/'        => {
			'title' => 'Bratislava Perl Mongers',
		},
		'http://kamilla.schatz.cuvi.info/' => {
			'title' => 'Kamilla Schatz',
		},
		'http://trac.cle.sk/' => {
			'title' => 'Available Projects',
		},
		'https://cle.sk/trac/' => {
			'title' => 'Available Projects',
		},
		'http://svn.cle.sk/repos/pub/' => {
			'title'   => undef,
			'content' => qr'DOCTYPE svn',
		},
		'https://cle.sk/repos/pub/' => {
			'title'   => undef,
			'content' => qr'DOCTYPE svn',
		},
	);
	
	foreach my $base_url (keys %sites) {
		$mech->get_ok($base_url, 'fetch '.$base_url);
		
		# test site title
		my %site = %{$sites{$base_url}};
		
		is($mech->title, $site{'title'}, 'check title')
			if exists $site{'title'};

		like($mech->content, $site{'content'}, 'check content')
			if exists $site{'content'};
		
		# fetch site links
		my $INTERNAL_LINKS_QR = qr{
			^
			(
				$base_url        # links starting with base url
				|
				(?![a-zA-Z]+:)  # and NOT starting with http: or mailto: or ftp: or ...
			)
		}xms;

		$mech->links_ok(
			# match the links that starts with base url or are without http(s) in the beginning
			[ $mech->find_all_links( url_regex => $INTERNAL_LINKS_QR ) ],
			'check all internal page links',
		);
	}
	
	return 0;
}

