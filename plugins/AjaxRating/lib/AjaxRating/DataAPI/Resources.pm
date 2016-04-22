package AjaxRating::DataAPI::Resources {

    use strict;
    use warnings;

    # Add a `ratings` hash to an entry object in the data API.
    sub entry_summary {
        return [
            {   name             => 'ratings',
                from_object      => \&from_object,
                bulk_from_object => sub {
                    my ( $entries, $hashes ) = @_;
                    my $i = 0;
                    $hashes->[$i++]->{ratings} = from_object( $_ )
                        foreach @$entries;
                },
            }
        ];
    }

    sub from_object {
        my ( $entry ) = @_;
        my $app       = MT->instance;
        my $Summary   = $app->model('ajaxrating_votesummary');
        my $Vote      = $app->model('ajaxrating_vote');
        my %terms     = ( obj_type => 'entry', obj_id => $entry->id );
        my $data      = {};

        # Add current user's rating, if one exists
        my $user = $app->user;
        if ( $user && $user->id ) { # Saved and not anonymous
            if ( my $vote = $Vote->load({ voter_id => $user->id, %terms }) ) {
                $data->{userRating} = 0 + $vote->score;
            }
        }

        my %map = ( # MT uses camel-case for the Data API
            avg_score   => 'averageScore',
            total_score => 'totalScore',
            vote_count  => 'voteCount',
        );
        my $summary       = $Summary->get_by_key( \%terms );
        $data->{$map{$_}} = 0 + ($summary->$_||0) foreach keys %map;

        return $data;
    }
}

1;

__END__
