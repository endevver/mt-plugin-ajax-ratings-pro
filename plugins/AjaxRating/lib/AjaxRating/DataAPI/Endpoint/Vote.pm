package AjaxRating::DataAPI::Endpoint::Vote {

    use strict;
    use warnings;
    use 5.0101;  # Perl v5.10.1 minimum
    use Try::Tiny;
    use MT::DataAPI::Endpoint::Common;
    use MT::DataAPI::Resource;
    use AjaxRating::DataAPI::Endpoint::Common;

    sub list {
        my ( $app, $endpoint )         = @_;
        my ( $terms, $args, $options ) = setup_request( $app, $endpoint )
            or return;

        my $res = filtered_list( $app, $endpoint, 'ajaxrating_vote',
                                 $terms, $args, $options);
        return unless $res;

        my $items
            = MT::DataAPI::Resource::Type::ObjectList->new($res->{objects});

        return +{
            totalResults => $res->{count} + 0,
            itemCount    => scalar @{ $res->{objects} || [] },
            items        => $items,
        };
    }

    sub add {
        my ( $app, $endpoint ) = @_;
        my ( $terms, $args, $options )
            = setup_request( $app, $endpoint, 'score' ) or return;

        my $vote = $app->model('ajaxrating_vote')->new();
        $vote->set_values($terms);

        save_object( $app, 'ajaxrating_vote', $vote ) or return;

        $vote;
    }

    sub fetch {
        my ( $app, $endpoint ) = @_;
        my ( $terms, $args, $options )
            = setup_request( $app, $endpoint, 'voter_id' )
                or return;

        my $type = 'ajaxrating_vote';
        my $Vote = MT->model( $type );
        my $vote = $Vote->load($terms);
    }

    sub fetch_by_id {
        my ( $app, $endpoint ) = @_;
        my ( $terms, $args );

        return $app->error( 'Unauthorized', 401 )
            unless $app->user && $app->user->is_superuser;

        my $type = 'ajaxrating_vote';
        my $Vote = MT->model( $type );
        my $id   = $app->param('vote_ids')
            or return $app->error('Missing parameter: vote_ids');

        return $Vote->load($id) unless $id =~ m{,};

        $terms->{id} = [ split( /\s*,\s*/, $id ) ];
        $args->{limit}   = scalar @{ $terms->{id} };

        my $res = filtered_list( $app, $endpoint, $type, $terms, $args);

        return unless $res;

        my $items
            = MT::DataAPI::Resource::Type::ObjectList->new($res->{objects});

        return +{
            totalResults => $res->{count} + 0,
            itemCount    => scalar @{ $res->{objects} || [] },
            items        => $items,
        };
    }

    sub remove {
        my ( $app, $endpoint ) = @_;
        my ( $terms, $args, $options )
            = setup_request( $app, $endpoint, 'voter_id' ) or return;

        my $vote = MT->model( 'ajaxrating_vote' )->load( $terms, $args )
            or return $app->error( 'Vote not found', 404 );

        remove_object( $app, 'ajaxrating_vote', $vote ) or return;

        $vote;
    }

    sub remove_by_id {
        my ( $app, $endpoint ) = @_;

        return $app->error( 'Unauthorized', 401 )
            unless $app->user && $app->user->is_superuser;

        my $Vote  = $app->model('ajaxrating_vote');
        my @ids   = split( /\s*,\s*/, $app->param('vote_ids')||'' )
            or return +{ error => 'Missing parameter: vote_ids' };

        my @votes = $app->model('ajaxrating_vote')->load(
            @ids > 1 ? { id => \@ids } : $ids[0]
        );

        my %results;
        my %ids   = map { $_ => 1 } @ids;
        foreach my $vote ( @votes ) {
            delete $ids{$vote->id};

            if ( $vote->remove ) {
                push( @{ $results{removed} }, $vote );
            }
            else {
                push( @{ $results{not_removed} },
                    { error => $vote->errstr||'Unknown error',
                      vote  => $vote }
                );
            }
        }

        push( @{ $results{not_found} },
            { error => "Vote ID $_ not found" } ) foreach keys %ids;

        return \%results;
    }
}

1;

__END__

