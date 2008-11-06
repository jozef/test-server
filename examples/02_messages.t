#!/usr/bin/perl

=head1 NAME

message.t - checks a file(s) and generates failed tests on every line found there

=head SYNOPSIS

	cat >> test-server.yaml << __YAML_END__
		message:
			- messages.log
	__YAML_END__

=head1 DESCRIPTION

The purpouse of this test is to allow any program in the system to pass messages
to the monitoring simply by adding line into a file.

Each line in the given file (except empty lines) will generate a failed test.
If there are no lines in the files then there will be just a single passed
test.

The file names in the configuration are relative to the folder where this test
script is running. Programs can write into that folder or it should be simple
to symlink to any file in the system or create a folder with symlinks if there
will be more files to be checked.

=cut

use strict;
use warnings;

use Test::More;
#use Test::More tests => 1;
use YAML::Syck 'LoadFile';
use FindBin '$Bin';
use File::Slurp 'read_file';

my $config = LoadFile($Bin.'/test-server.yaml');
my $DEFAULT_MESSAGE_FILE = 'messages.log';

# override the defaults
if (not exists $config->{'message'}) {
	$config->{'message'} = [ $DEFAULT_MESSAGE_FILE ];
}

exit main();

sub main {
	# read all lines from message files
	my %lines = map {
		$_ => [
			grep { $_ !~ /^\s*$/xms }         # skip empty lines
			eval { read_file($Bin.'/'.$_) }   # read all lines from a file
		]
	} @{$config->{'message'}};
	
	# count number of messages
	my $number_of_messages = scalar map { @{$lines{$_}} } keys %lines;
	
	# everyting is fine if no message lines were found
	if (not $number_of_messages) {
		plan 'tests' => 1;
		ok(1, 'all ok no messages to pass');
		return 0;
	}

	plan 'tests' => $number_of_messages;
	
	# create one failed test per message line
	foreach my $filename (keys %lines) {
		foreach my $line (@{$lines{$filename}}) {
			chomp $line;
			ok(0, "$filename: $line");
		}
	}
		
	return 0;
}


__END__

=head1 AUTHOR

Jozef Kutej

=cut
