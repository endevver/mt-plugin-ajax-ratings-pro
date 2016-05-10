package AjaxRating::DataAPI {

    use strict;
    use warnings;
    use 5.0101;  # Perl v5.10.1 minimum
    use Try::Tiny;
    use MT::DataAPI::Endpoint::Common;
    use MT::DataAPI::Resource;
    # use DDP;

    sub setup_request {
        my ( $app, $endpoint, @required ) = ( @_, qw( obj_type obj_id ));
        my ( $terms, $args, $options );

        $app->param( 'format',    $app->param('format')    || 'json'    );
        $app->param( 'direction', $app->param('direction') || 'descend' );

        my %param = $app->param_hash;

        my $blog_id   = $app->param('site_id') || $app->param('blog_id');
        if ( my $blog = MT->model('blog')->load( $blog_id ) ) {
            $app->blog( $blog );
            $terms->{blog_id} = $blog_id;
        }

        # Only allow voter_id to be the ID of the logged in user
        try   { $param{voter_id} = $app->user->id or die }
        catch { delete $param{voter_id}                  };

        unless ( $param{obj_id} ) {
            my $id_field   = ($param{obj_type} || '').'_id';
            my $obj_id     = delete $param{$id_field};
            $param{obj_id} = $obj_id if $obj_id;
        }

        my @missing
            = grep { ! defined( $terms->{$_} = $param{$_} ) } @required;

        if ( @missing ) {
            my $missing = join(', ', @missing );
            # p %{{ $app->param_hash }};
            return $app->error("Required parameters not found: $missing");
        }

        if ( $terms->{obj_id} =~ m{,} ) {
            if ( $app->request_method eq 'POST' ) {
                return $app->error(
                    'You cannot make a POST request against multiple objects' );
            }
            $terms->{obj_id} = [ split( /\s*,\s*/, $terms->{obj_id} ) ];
            $args->{limit}   = scalar @{ $terms->{obj_id} };
        }

        $args->{limit} ||= $param{limit} || 10;

        return ( $terms, $args, $options ) unless @missing;
    }

    sub get_votesummary {
        my ( $app, $endpoint )         = @_;
        my ( $terms, $args, $options ) = setup_request( $app, $endpoint );

        return unless $terms;

        my $res = filtered_list( $app, $endpoint, 'ajaxrating_votesummary',
                                 $terms, $args, $options );
        return unless $res;

        my $items
            = MT::DataAPI::Resource::Type::ObjectList->new($res->{objects});

        return +{
            totalResults => $res->{count} + 0,
            itemCount    => scalar @{ $res->{objects} || [] },
            items        => $items,
        };
    }

    sub get_votes {
        my ( $app, $endpoint )         = @_;
        my ( $terms, $args, $options ) = setup_request( $app, $endpoint );

        return unless $terms;

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

    sub add_vote {
        my ( $app, $endpoint ) = @_;
        my ( $terms, $args, $options )
            = setup_request( $app, $endpoint, 'score' );

        return unless $terms;

        my $vote = $app->model('ajaxrating_vote')->new();
        $vote->set_values($terms);

        save_object( $app, 'ajaxrating_vote', $vote ) or return;

        $vote;
    }

    sub remove_vote {
        my ( $app, $endpoint ) = @_;
        my ( $terms, $args, $options )
            = setup_request( $app, $endpoint, 'voter_id' );
        my $type = 'ajaxrating_vote';
        my $Vote = MT->model( $type );

        return unless $terms;

        # To ensure the post_remove callback is called, we load then remove
        # via the object method. Otherwise, the driver's direct_remove method
        # is called which doesn't trigger the post_remove callbacks
        my $vote = $Vote->load( $terms, $args )
            or return $app->error( 'Vote not found', 404 );

        $app->param('voter_id', $terms->{voter_id} );
        return unless run_permission_filter(
            $app, 'data_api_delete_permission_filter', $Vote, $vote );

        unless ( $vote->remove ) {
            my $msg = 'Removing [_1] failed: [_2]';
            my @args = ( $vote->obj_type.' '.$vote->obj_id, $vote->errstr);
            return $app->error( $app->translate( $msg, @args ), 500 );
        }

        $app->run_callbacks( 'data_api_post_delete.' . $type, $app, $vote );
        return $vote;
    }

    sub remove_vote_by_id {
        my ( $app, $endpoint ) = @_;
        my $Vote  = $app->model('ajaxrating_vote');
        my @ids   = split( /\s*,\s*/, $app->param('vote_id')||'' )
            or return +{ error => 'No vote_id specified' };

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
