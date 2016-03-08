package AjaxRating::DataAPI {

    use strict;
    use warnings;
    use MT::DataAPI::Endpoint::Common;
    use MT::DataAPI::Resource;
    use Scalar::Util qw( looks_like_number );
    use AjaxRating;

    sub get_votesummary {
        my ( $app, $endpoint ) = @_;

        $app->param('obj_ids', $app->param('obj_id'))
            unless $app->param('obj_ids');

        unless ( $app->param('obj_ids') ) {
            my $id_field = ($app->param('obj_type') || '').'_id';
            $app->param('obj_ids', $app->param($id_field));
        }

        my $result = AjaxRating->get_votesummary({ $app->param_hash });
        return $app->error( $result->{error} ) if $result->{error};

        my @converted;
        foreach my $obj ( @{ $result->{items} } ) {
            push( @converted, obj_to_json_hash( $obj ) );
        }
        $result->{items} = \@converted;

        return $result->{totalResults} == 1 ? shift( @converted )
                                            : $result;
    }

    sub add_vote {
        my ( $app, $endpoint ) = @_;

        my $voter = $app->user;
        $app->param( 'voter_id', $voter->id ) if $voter;

        unless ( $app->param('obj_id') ) {
            my $obj_type = $app->param('obj_type') || '';
            $app->param( 'obj_id', $app->param($obj_type.'_id') );
        }

        $app->param( 'score', ($app->param('r') // $app->param('rating')) )
            unless defined $app->param('score');

        my $vote = $app->model('ajaxrating_vote')->new();
        $vote->set_values({
            ( $voter ? (voter_id => $voter->id) : () ),
            map  { $_ => $app->param($_)   }
                grep { defined $app->param($_) }
                    qw( blog_id obj_type obj_id score )
        });

        # my $new_vote = $app->resource_object( 'ajaxrating_vote', $vote ) or return;
        # my $post_save = build_post_save_sub( $app, $blog, $new_vote, $vote );

        save_object( $app, 'ajaxrating_vote', $vote )
            or return;

        # $post_save->();

        ### TODO The following should be move to a Vote resource
        my ( $votesummary ) = $app->model('ajaxrating_votesummary')->load({
            map  { $_ => $vote->$_ }
                grep { defined $vote->$_ } qw( blog_id obj_type obj_id )
        });

        my $vsummary  = obj_to_json_hash( $votesummary );
        my $vote_hash = obj_to_json_hash( $vote );

        return +{
            score => $vote->score + 0 ,
            ( map { $_ => $vote_hash->{$_} }
                    qw( id blog_id ip obj_type obj_id score voter_id ) ),
            votesummary => {
                map { $_ => $vsummary->{$_} }
                    qw( avg_score total_score vote_count vote_dist ),
            },
        };
    }

    sub remove_vote {
        my ( $app, $endpoint ) = @_;

        my $voter = $app->user;
        $app->param( 'voter_id', $voter->id ) if $voter;

        unless ( $app->param('obj_id') ) {
            my $obj_type = $app->param('obj_type') || '';
            $app->param( 'obj_id', $app->param($obj_type.'_id') );
        }

        $app->param('obj_ids', $app->param('obj_id'))
            unless $app->param('obj_ids');

        unless ( $app->param('obj_ids') ) {
            my $id_field = ($app->param('obj_type') || '').'_id';
            $app->param('obj_ids', $app->param($id_field));
        }

        my $result = AjaxRating->remove_vote({ $app->param_hash });
        return $app->error( $result->{error} ) if $result->{error};

        $result->{$_} = obj_to_json_hash( $result->{$_} )
            foreach keys %$result;

        return $result;
    }

    sub remove_vote_by_id {
        my ( $app, $endpoint ) = @_;

        my @results;
        foreach my $vote_id ( split( /\s?,\s?/, $app->param('vote_id') ) ) {
            if ( my $vote = $app->model('ajaxrating_vote')->load($vote_id) ) {
                my $result = AjaxRating->remove_vote( $vote->get_values );
                # p $result;
                $result->{$_} = obj_to_json_hash( $result->{$_} )
                    for keys %$result;
                push( @results, $result );
            }
            else { warn "Vote ID $vote_id not found" }
        }

        return +{ removed => \@results };
    }

    sub obj_to_json_hash {
        my $obj   = shift or return {};
        my $props = $obj->properties;
        my $item  = $obj->get_values();
        foreach my $k ( @{$obj->column_names} ) {
            # Set default for column if undefined
            my ( $def, $type ) = map { $props->{column_defs}{$k}{$_} }
                                    qw( default type );
            $item->{$k} //= $def if defined $def;

            # Explicitly convert to proper data type for JSON outpit
            $item->{$k} = $item->{$k} + 0
                if (grep { $type eq $_ } qw( float integer ));

            $item->{$k}
                = MT::Util::ts2iso( $item->{blog_id}, $item->{$k} )
                        if $type eq 'datetime';
        }
        return $item;
    }
}

1;
