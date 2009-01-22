use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'MIME::Type::Simple',
    license             => 'perl',
    dist_author         => 'Robert Rothenberg <rrwo at cpan.org>',
    dist_version_from   => 'lib/MIME/Type/Simple.pm',
    requires => {
        'Carp'          => 0,
        'Storable'      => 0,
        'Sub::Exporter' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    create_readme      => ($Module::Build::VERSION >= 0.2702),
    add_to_cleanup      => [ 'MIME-Type-Simple-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
