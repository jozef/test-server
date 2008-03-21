#!/usr/bin/perl

=head1 NAME

folder-file.t - check sizes and permittions

=head SYNOPSIS

	cat >> test-server.yaml << __YAML_END__
	folder-file:
	    /var/log/apache2:
	        user: root
	        group: root
	        max-size: 500M
	        perm: 755
	    /var/tmp:
	        max-size: 250M
        /tmp/non-existing:
	    /tmp/test-file:
	        perm: 2775
	        max-size: 250M
	__YAML_END__

=cut

use strict;
use warnings;

use Test::More;
use Test::Differences;
use YAML::Syck 'LoadFile';
use FindBin '$Bin';
use Filesys::DiskUsage qw/du/;

my $STAT_PERM = 2;
my $STAT_UID  = 4;
my $STAT_GID  = 5;

my $config = LoadFile($Bin.'/test-server.yaml');

plan 'skip_all' => "no configuration sections for 'folder-file' "
	if (
		not $config
		or not $config->{'folder-file'}
	);
$config = $config->{'folder-file'};


exit main();

sub main {
	my $tests = 0;
	my %folder_with_name = %{$config};
	foreach my $folder (keys %folder_with_name) {
		$tests++;
		$tests+= keys %{$folder_with_name{$folder}};
	}

	plan 'skip_all' => 'no tests defined'
		if not $tests;
	plan 'tests' => $tests;
	
	foreach my $folder (keys %folder_with_name) {
		my %folder_checks = %{$folder_with_name{$folder}};
		
		SKIP: {
			# check if readable for us
			ok(-r $folder, 'is folder '.$folder.' readable')
				or skip 'skipping '.$folder.', not readable', (keys %folder_checks);
			
			# check size
			my $size = $folder_checks{'max-size'};
			if ($size) {
				my $du_size = du($folder);
				cmp_ok($du_size, '<', decode_size($size), 'check '.$folder.' size < '.$size)
					or diag($folder.' has '.format_size($du_size));
			}
			
			my @folder_stat = stat($folder);
			
			# check user
			my $uid;
			my $user = $folder_checks{'user'};
			if ($user) {
				$uid = $user;
				$uid = getpwnam($user)
					if $user !~ m{^\s*\d+\s*$};
				
				# check the uid, if we have a number
				if ((defined $uid) and ($uid =~ m{^\s*\d+\s*$})) {
					my $folder_uid = $folder_stat[$STAT_UID];
					is($folder_uid, $uid, 'check folder '.$folder.' uid');
				}
				else {
					ok(0, 'wrong username: '.$user);
					$uid = undef;
				}
			}
			
			# check group
			my $gid;
			my $group = $folder_checks{'group'};
			if ($group) {
				$gid = $group;
				$gid = getgrnam($group)
					if $group !~ m{^\s*\d+\s*$};
				
				# check the gid, if we have a number
				if ((defined $gid) and ($gid =~ m{^\s*\d+\s*$})) {
					my $folder_gid = $folder_stat[$STAT_GID];
					is($folder_gid, $gid, 'check folder '.$folder.' gid');
				}
				else {
					ok(0, 'wrong group: '.$group);
					$gid = undef;
				}
			}
			
			# check perms
			my $perm = $folder_checks{'perm'};
			if ($perm) {
				my $folder_perm = sprintf '%lo', $folder_stat[$STAT_PERM] & 07777; # mask away the file type
				is($folder_perm, $perm, 'check folder '.$folder.' mode')
					or diag 'folder permissions in oct '.(sprintf '%lo', $folder_perm).' expecting '.$perm;
			}
			
			# check recursively
			eq_or_diff(
				[ check_recursively($folder, $folder_checks{'recurse'}, $uid, $gid, $perm) ],
				[],
				'check uid,gid,permissions recursively',
			);
		}
	}	
		
	return 0;
}

sub check_recursively {
	my ($filename, $recurse, $uid, $gid, $perm) = @_;
	
	return
		if ((not $filename) or (not -d $filename));
	
	my @bad_files;
	my @files_to_check = ($filename);
	
	while (my $filename = pop @files_to_check) {
		my @stat = stat($filename);
		
		my $file_uid  = $stat[$STAT_UID];
		my $file_gid  = $stat[$STAT_UID];
		my $file_perm = sprintf '%lo', $stat[$STAT_PERM] & 07777;
		
		push @bad_files, 'bad uid for '.$filename.': '.$file_uid.' does not match '.$uid
			if ((defined $uid) and ($file_uid != $uid));
		push @bad_files, 'bad gid for '.$filename.': '.$file_gid.' does not match '.$gid
			if ((defined $gid) and ($file_gid != $gid));
		push @bad_files, 'bad permissions for '.$filename.': '.(sprintf '%lo', $file_perm).' does not match '.$perm
			if ((defined $perm) and ($file_perm != $perm));

		if ($recurse and (-d $filename)) {
			opendir(my $dir_handle, $filename) || return;
			while (my $filename_to_check = readdir($dir_handle)) {
				next if $filename_to_check eq '.';
				next if $filename_to_check eq '..';
				push @files_to_check, File::Spec->catfile($filename, $filename_to_check);
			}
			closedir($dir_handle);
		}
	}
	
	return @bad_files;
}

sub decode_size {
	my $size = shift;
	
	return
		if not defined $size;
	
	die 'failed to parse size: '.$size
		if ($size !~ m/\b([0-9]+)\s*([MKG])\s*$/);
	
	$size    = $1;
	my $unit = $2;
	
	if (defined $unit) {
		  $unit eq 'G' ? $size *= 1024*1024*1024
		: $unit eq 'M' ? $size *= 1024*1024
		: $unit eq 'K' ? $size *= 1024
		: die 'shoud never happend... but if enjoy! ;)';
	}
	
	return $size;
}

sub format_size {
	my $size = shift;
	
	my $unit = '';
	
	if ($size > 1024*2) {
		$size = int($size/1024);
		$unit = 'K';
	}
	if ($size > 1024*2) {
		$size = int($size/1024);
		$unit = 'M';
	}
	if ($size > 1024*2) {
		$size = int($size/1024);
		$unit = 'G';
	}
	
	return $size.$unit;
}


__END__

=head1 TODO

recursive

=head1 AUTHOR

Jozef Kutej

=cut
