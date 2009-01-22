#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'MIME::Type::Simple' );
}

diag( "Testing MIME::Type::Simple $MIME::Type::Simple::VERSION, Perl $], $^X" );
