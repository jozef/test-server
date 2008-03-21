use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
	module_name         => 'Test::Server',
	license             => 'perl',
	dist_author         => 'Jozef Kutej <jozef@kutej.net>',
	dist_version_from   => 'lib/Test/Server.pm',
	build_requires      => {
    },
	requires            => {
		'Test::More'            => 0,
		'Test::Differences'     => 0,
		'Test::Exception'       => 0,
    	'YAML::Syck'            => 0,
    	'Socket'                => 0,
    	'List::MoreUtils'       => 0,
    	'Carp::Clan'            => 0,
    	'Class::Accessor::Fast' => 0,
    	'File::Slurp'           => 0,
    	'Filesys::DiskUsage'    => 0,
	# Sys::Net dependecies
    	'IO::Socket::INET'      => 0,
    },
    recommends          => {
    	'Net::DNS::Resolver'   => 0,
    	'Test::WWW::Mechanize' => 0,
    	'Proc::ProcessTable'   => 0,
    	'Net::NTP'             => 0,
    	'Time::HiRes'          => 0,
    },
    add_to_cleanup      => [ 'Test-Server-*' ],
    create_makefile_pl  => 'traditional',
    sign                => 1,
    create_readme       => 1,
);

$builder->create_build_script();
