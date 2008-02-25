use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Test::Server',
    license             => 'perl',
    dist_author         => 'Jozef Kutej <jozef@kutej.net>',
    dist_version_from   => 'lib/Test/Server.pm',
    build_requires      => {
        'Test::More' => 0,
    },
    requires            => {
    },
    recommends          => {
    },
    add_to_cleanup      => [ 'Test-Server-*' ],
#    create_makefile_pl  => 'traditional',
    sign                => 1,
#    create_readme       => 1,
    
);

$builder->create_build_script();
