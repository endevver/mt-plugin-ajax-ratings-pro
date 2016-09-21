package AjaxRating::DataAPI::Resource::Foreign;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use MT;
use AjaxRating::Types;
use AjaxRating::Util qw( obj_to_type );

# Adds a `ratings` hash to foreign object data JSON
sub fields {
    [
        {   name             => 'ratings',
            from_object      => \&from_object,
            bulk_from_object => sub {
                my ( $objs, $hashes ) = @_;
                my $i = 0;
                $hashes->[$i++]->{ratings} = from_object( $_ )
                    foreach @$objs;
            },
        }
    ];
}

sub from_object {
    my ( $obj )      = @_;
    my ( $obj_type ) = obj_to_type( $obj );
    my $enabled      = AjaxRating::Types->enabled_types();

    my $data = {};
    return $data unless grep { $_ eq $obj_type } keys %$enabled;

    my $app        = MT->instance;
    state $Summary = $app->model('ajaxrating_votesummary');
    state $Vote    = $app->model('ajaxrating_vote');

    my %terms      = ( obj_type => $obj_type, obj_id => $obj->id );

    # Add current user's rating, if one exists
    my $user = $app->user;
    if ( $user && $user->id ) { # Saved and not anonymous
        if ( my $vote = $Vote->load({ voter_id => $user->id, %terms }) ) {
            $data->{userRating} = 0 + $vote->score;
        }
    }

    my %map = ( # MT uses camel-case for the Data API
        avg_score   => 'avgScore',
        total_score => 'totalScore',
        vote_count  => 'voteCount',
    );
    my $summary       = $Summary->get_by_key( \%terms );
    $data->{$map{$_}} = 0 + ($summary->$_||0) foreach keys %map;

    return $data;
}

1;

__END__
