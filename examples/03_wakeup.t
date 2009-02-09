#!/usr/bin/perl

=head1 NAME

wakeup.t - wakeup monitoring team

=head SYNOPSIS

	cat >> test-server.yaml << __YAML_END__
	wakeup:
	    period  : 30d
	    filename: /var/tmp/wakeup-state
	__YAML_END__

=head1 DESCRIPTION

After given number of days a fail test will occure. The purpose is to make sure
monitoring team is receiving alarms properly. If the admins finds out that this
test fails for couple of days without anyone notice then there is something
wrong.

=cut

use strict;
use warnings;

#use Test::More;
use Test::More tests => 2;
use Test::Differences;
use YAML::Syck 'LoadFile';
use FindBin '$Bin';
use POSIX 'strftime';

my $config = LoadFile($Bin.'/test-server.yaml');


exit main();

sub main {
	my $period          = $config->{'wakeup'}->{'period'} || '90d';
	my $wakeup_filename = $config->{'wakeup'}->{'filename'} || '/var/tmp/wakeup-state';
	
	die 'period should have format like "90d" for 90 days'
		if $period !~ /^(\d+)d$/;
	my $period_seconds = $1*24*60*60;
	
	my $mtime = (stat($wakeup_filename))[9];
	
	SKIP: {
		skip 'file '.$wakeup_filename.' does not exists', 1
			if not defined $mtime;
		
		my $max_mtime = $mtime+$period_seconds;
		
		diag 'last notification was on '.strftime("%a %b %e %H:%M:%S %Y", localtime($mtime));
		if (time() > $max_mtime) {
			ok(0, 'time to wakeup, notify someone to touch "'.$wakeup_filename.'" '.int((time() - $max_mtime)/60/60/24).' days overdue (low priority alarm)');
		}
		else {
			ok(1, 'next will be     on '.strftime("%a %b %e %H:%M:%S %Y", localtime($max_mtime)));
		}
	}
	
	SKIP: {
		skip 'creation of wakeup file "'.$wakeup_filename.'" as it exists', 1
			if $mtime;
		
		ok(open(my $fh, '>', $wakeup_filename), 'create '.$wakeup_filename)
	}
	
	return 0;
}


__END__

=head1 AUTHOR

Jozef Kutej

=cut
