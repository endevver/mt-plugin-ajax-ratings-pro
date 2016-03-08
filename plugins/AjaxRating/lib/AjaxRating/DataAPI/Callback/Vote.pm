package AjaxRating::DataAPI::Callback::Vote {

    use strict;
    use warnings;

    ### FIXME This save filter should be applied to all saves, not just Data API
    ### but that requires more refactoring than which has been done to enable
    ### Data API access.
    sub save_filter {
        my ( $cb, $app, $obj, $obj_orig ) = @_;

        # REQUIRED FIELDS
        my @required     = qw( blog_id obj_type obj_id score );
        ### TODO Decision: Should ratings of things which are not child objects  of a blog be allowed? (i.e. no blog_id; e.g. authors)

        # MIN/MAX SCORE
        my ( $min_score, $max_score ) = ( undef, 10 );
        ### FIXME Why is 10 the max score? It's both arbitrary and limiting
        ### FIXME Should negative votes be allowed?
        ### If so, votesummary arithmetic should be validated throughout
        my $plugin     = MT->instance->component('ajaxrating');
        my $config     = $plugin->get_config_hash('blog:'.$obj->blog_id) || {};
        my $check_ip
            = $plugin->get_config_value('enable_ip_checking', 'system');
        my $check_type = $config->{ratingl};

        ### REQUIRED VALUES CHECK
        if ( my @missing = grep { ! defined( $obj->$_ ) } @required ) {
            return $app->error(
                ref($obj) .' object save blocked for missing fields: '
                          . join( ', ',@missing ) );
        }

        my $type = $obj->obj_type;
        my %terms = ( obj_type => $type, obj_id => $obj->obj_id );

        ### SCORE VALUE BOUNDARY CHECK
        # Refuse votes that exceed the maximum number of scoring points.
        my $max  = $config->{$type . "_max_points"} // $max_score;
        my $min  = $config->{$type . "_min_points"} // $min_score;
        return $app->error(
                'Specified score exceeds the maximum for this item.' )
            if defined $max and $obj->score > $max;
        return $app->error(
                'Specified score exceeds the minimum for this item.' )
            if defined $min and $obj->score < $min;

        ### VALID OBJECT TYPE CHECK
        # Check that this vote's obj_type is valid for this blog
        if ( $check_type ) {
            return $app->error( 'Invalid object type specified: '.$type )
                unless grep { $type eq $_ } qw( entry blog );
        }

        ### DUPLICATE VOTE CHECK - IP ADDRESS
        # If IP address checking is enabled, return an error if we already have
        # a vote from the current IP address (assuming that's defined)
        $obj->ip( eval { MT->instance->remote_ip } ) unless $obj->ip;
        if ( $check_ip && $obj->ip ) {
            return $app->error(
                    'Your IP address has already voted on this item.')
                if ref($obj)->exist({ %terms, ip => $obj->ip });
        }

        ### DUPLICATE VOTE CHECK - USER
        # Return error if vote exists from current logged-in user, if exists
        unless ( my $voter_id = $obj->voter_id ) {
            # Determine the user's identity - First try commenter session
            my ( $session, $voter ) = eval { $app->get_commenter_session };
            # If not defined, fall back to MT user record
            $voter //= eval { $app->user };
            $obj->voter_id( $voter->id ) if $voter;
        }

        if ( $obj->voter_id ) {
            return $app->error('You have already voted on this item.')
                if ref($obj)->exist({ %terms, voter_id => $obj->voter_id });
        }
        else {
            warn sprintf "No voter_id in %s record: %s",
                ref($obj), $obj->to_hash();
        }

        return 1;
    }

    ### FIXME This post_save callback should be applied to all saves, not just Data API
    ### but that requires more refactoring than which has been done to enable
    ### Data API access.
    sub post_save {
        my ( $cb, $app, $obj, $obj_orig ) = @_;

        # Update the Vote Summary. The summary is used because it will let
        # publishing happen faster (loading one summary row to publish results
        # is faster than loading many AjaxRating::Vote records).
        my $votesummary = $app->model('ajaxrating_votesummary')->get_by_key({
            obj_type => $obj->obj_type,
            obj_id   => $obj->obj_id,
        });
        $votesummary->add_vote( $obj );

        # Now that the vote has been recorded, rebuild the required pages.
        AjaxRating->rebuild_vote_object( $obj );

        return 1;
    }
}

1;
