#!/usr/local/bin/perl

use Test::More;
use Class::Load qw( try_load_class );
use DDP;

BEGIN {
    for (qw( Test::AjaxRating::Tools Test::MT::Suite )) {
        my ( $loaded, $error ) = try_load_class($_);
        BAIL_OUT "Could not load $_: $error" unless $loaded;
    }
}

use Test::AjaxRating::Tools;
use Test::MT::Suite;

my $suite = new_ok( 'Test::MT::Suite' );
my $app = MT->instance();
isa_ok( $app, $ENV{MT_APP}, "MT App: ".$ENV{MT_APP} );


done_testing();

__END__
