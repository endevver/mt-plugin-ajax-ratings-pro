package AjaxRating::CMS;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum

# From the Vote Activity Log (listing framework), delete a vote or votes.
sub vote_delete {
    my ($app) = @_;
    my $q     = $app->can('query') ? $app->query : $app->param;
    my @ids   = $app->param('id');

    # The log record is saved to the system Activity Log. We want to log the
    # deleted vote because it's something significant and could skew results,
    # so we want to track who did this.
    require Data::Dumper;

    foreach my $id (@ids) {
        my $vote = $app->model('ajaxrating_vote')->load($id)
            or next;
        $vote->remove or die $vote->errstr;

        # Recalculate the Vote Summary record.
        my $vsumm = $vote->rebuild_votesummary_record();

        # Get a string of the dumped record to insert in the Activity Log.
        my $dumped_vote = Data::Dumper->Dump([$vote->{column_values}]);

        $app->log({
            level     => $app->model('log')->INFO(),
            class     => 'ajaxrating',
            category  => 'vote',
            author_id => $app->user->id,
            message   => 'A Vote Log Record has been deleted.',
            metadata  => $dumped_vote,
        });
    }

    $app->add_return_arg( deleted => 1 );
    $app->call_return;
}

# From the Vote Activity Log (listing framework), recalulate summaries. This is
# a particularly important option when a summary hasn't been created for a vote
# for some reason.
sub vote_recalculate_votesummary {
    my ($app) = @_;
    my @ids   = $app->param('id');

    foreach my $id (@ids) {
        # Use the Vote to rebuild a Vote Summary.
        my $vote = $app->model('ajaxrating_vote')->load($id)
            or next;

        # Recalculate the Vote Summary record.
        my $vsumm = $vote->rebuild_votesummary_record();
    }

    $app->add_return_arg( recalculated => 1 );
    $app->call_return;
}

# From the Vote Summary Activity Log (listing framework), recalculate summaries.
sub votesummary_recalculate {
    my ($app) = @_;
    my @ids   = $app->param('id');

    foreach my $id (@ids) {
        my $vsumm = $app->model('ajaxrating_votesummary')->load($id)
            or next;

        # Recalculate the Vote Summary record.
        my $new_vsumm = $vsumm->rebuild_votesummary_record();
    }

    $app->add_return_arg( recalculated => 1 );
    $app->call_return;
}

# From the Vote Summary Activity Log (listing framework), delete a Vote Summary
# record and all related Vote records.
sub votesummary_delete {
    my ($app) = @_;
    my @ids   = $app->param('id');

    # The log record is saved to the system Activity Log. We want to log the
    # deleted vote because it's something significant and could skew results,
    # so we want to track who did this.
    require Data::Dumper;

    foreach my $id (@ids) {
        my $summ = $app->model('ajaxrating_votesummary')->load($id)
            or next;
        $summ->remove or die $summ->errstr;

        my $iter = $app->model('ajaxrating_vote')->load_iter({
            obj_type => $summ->obj_type,
            obj_id   => $summ->obj_id,
        });

        my $vote_counter = 0;
        while (my $vote = $iter->() ) {
            $vote->remove or die $vote->errstr;
            $vote_counter++;
        }

        # Get a string of the dumped record to insert in the Activity Log.
        my $dumped_record = Data::Dumper->Dump([$summ->{column_values}]);

        $app->log({
            level     => $app->model('log')->INFO(),
            class     => 'ajaxrating',
            category  => 'votesummary',
            author_id => $app->user->id,
            message   => 'A Vote Summary Log Record has been deleted. '
                . 'Additionally, ' . $vote_counter . ' Vote Records for this '
                . 'Summary were also deleted.',
            metadata  => $dumped_record,
        });
    }

    $app->add_return_arg( deleted => 1 );
    $app->call_return;
}

# The listing properties for both the vote and vote summary screens both
# display an "object" column with the same links.
sub list_prop_object_content {
    my ( $prop, $obj, $app, $opts ) = @_;
    my $obj_id   = $obj->obj_id;
    my $obj_type = $obj->obj_type;
    my $edit_url = '';

    my $target_obj = $app->registry('object_types', $obj_type)
        && $app->model($obj_type)
        && $app->model( $obj_type )->load( $obj_id )
            or return 'Target object not found';

    if ( $obj_type =~ /entry|page/ ) {
        $edit_url = $app->uri(
            mode =>'view',
            args => {
                '_type'   => $target_obj->class,
                'id'      => $target_obj->id,
                'blog_id' => $target_obj->blog_id
            },
        );

        return $target_obj->title
        # Add the "Edit" link
            . ' <a target="_blank" href="' . $edit_url . '"><img src="'
            . $app->static_path . 'images/status_icons/draft.gif" '
            . 'width="9" height="9" alt="Edit" title="Edit" /></a>'
        # Add the "View" link
            .' <a target="_blank" href="' . $target_obj->permalink
            . '"><img src="' . $app->static_path
            . 'images/status_icons/view.gif" width="13" height="9" alt="View" '
            . 'title="View" /></a>';
    }
    elsif ( $obj_type eq 'comment' ) {
        $edit_url = $app->uri(
            mode =>'view',
            args => {
                '_type'   => 'comment',
                'id'      => $target_obj->id,
                'blog_id' => $target_obj->blog_id
            },
        );

        return substr( $target_obj->text, 0, 20 )
        # Add the "Edit" link
            . ' <a target="_blank" href="' . $edit_url . '"><img src="'
            . $app->static_path . 'images/status_icons/draft.gif" '
            . 'width="9" height="9" alt="Edit" title="Edit" /></a>';
    }
    else {
        return $target_obj->has_column('text')
            ? substr( $target_obj->text, 0, 20 )
            : $app->model($obj_type)->class_label;
    }
}

# Listing framework system filters for both the Vote and Vote Summary records.
sub system_filters {
    my $system_filters = {
        _obj_id => {
            label => sub {
                my $app = MT->instance;
                my ($type, $id) = split ':', $app->param('filter_val');
                return unless $type && $id;

                my $vote = $app->model('ajaxrating_vote')->load({
                    obj_type => $type,
                    obj_id   => $id,
                })
                    or die $app->error(
                        "Could not load Vote records of type $type and ID $id."
                    );

                return 'Votes on the ' . $vote->obj_type . ' object, ID '
                    . $vote->obj_id;
            },
            order => 100,
            items => sub {
                my $app = MT->instance;
                my ($type, $id) = split ':', $app->param('filter_val');

                return [
                    {
                        type => 'target_obj_type',
                        args => {
                            string  => $type,
                        },
                    },
                    {
                        type => 'obj_id',
                        args => {
                            option => 'equal',
                            value  => $id,
                        },
                    }
                ];
            },
        },
    };

    # We want to offer system filters for any object type that might be rated
    # with Ajax Rating, however the following only ever returns one value...
    # my $type = 'ajaxrating_vote';
    # my $column = 'obj_type';
    #
    # my $class  = MT->instance->model($type);
    # my $driver = $class->dbi_driver;
    # my $dbd    = $driver->dbd;
    # my $sql    = $dbd->sql_class->new();
    # my $table  = $class->table_name;
    # $sql->select([ $dbd->db_column_name($table, $column) ]);
    # # $sql->select(['*']);
    # $sql->from([ $table ]);
    # # $sql->distinct(1);
    # MT->log( "SQL: ".$sql->as_sql );
    #
    # my $dbh = $driver->r_handle or die 'Could not get driver handle';
    # my $sth = $dbh->prepare( $sql->as_sql ) or die 'Prepare failed';
    # $sth->execute(@{ $sql->{bind} }) or warn $dbh->errstr;
    # my @obj_types = $dbh->selectrow_array($sth);
    # MT->log("Object types: @obj_types");


    # Since the above didn't work, let's try to give some useful filters based
    # upon the objects in the system -- a safe starting point. Look for any
    # object whose type is used in the Vote records and make it a filter.
    my $app = MT->instance;
    my $obj_types = $app->registry('object_types');

    while (my $obj_type = each %$obj_types) {
        if (
            $app->model( $obj_type )
            && $app->model('ajaxrating_vote')->exist({
                obj_type => $obj_type,
            })
        ) {
            $system_filters->{'obj_type_' . $obj_type} = {
                label => 'Object Type: ' . $obj_type,
                items => sub {
                    return [
                        {
                            type => 'obj_type',
                            args => {
                                string => $obj_type,
                            },
                        }
                    ];
                }
            };
        }
    }

    return $system_filters;
}

# return $app->permission_denied()
#     unless $app->run_callbacks(
#     'cms_save_permission_filter.' . $t,
#     $app, $id, $vote );
# For the AddVote app, $id will be undef and $obj will be the vote $obj
sub can_save_vote {
    my ( $cb, $app, $id, $obj, $original ) = @_; # $original is Data API only

    check_request_method( $app ) or return;

    return 1;
}

# cms_save_filter.ajaxrating_vote
sub save_filter_vote {
    my ( $cb, $app, $obj, $orig ) = @_;  # $original is Data API only
    return 1;
}

# $app->run_callbacks( 'cms_pre_save.ajaxrating_vote', $app, $obj, $orig_obj )
sub pre_save_vote {
    my ( $cb, $app, $obj, $orig_obj ) = @_;

    # If this is a new vote, fill in defaults from app if possible
    unless ( $obj->id ) {
        # Use try() in case app doesn't have the necessary methods (e.g. MT)

        $obj->ip( $obj->ip || try { $app->remote_ip } );

        ### FIXME Need to get it directly from the app somewhere. Here?
        $obj->voter_id(   $obj->voter_id
                       || try { ($app->get_commenter_session)[1]->id }
                       || try { $app->user->id }        );

        $obj->blog_id(    $obj->blog_id
                       || try { $obj->object->blog_id }
                       || try { $app->blog->id }
                       || try {   $app->param('blog_id')
                               || $app->param('site_id') }  );
    }

    return 1;
}

# $app->run_callbacks( 'cms_post_save.ajaxrating_vote', $app, $obj, $orig_obj );
sub post_save_vote {
    my ( $cb, $app, $obj, $orig_obj ) = @_;

    # return ignored
}

# $app->run_callbacks(
#     'cms_post_bulk_save.ajaxrating_vote',
#     $app, \@objects );
sub post_bulk_save_votes {
    my ( $cb, $app, $objects ) = @_;

    # return ignored
}

# return $app->permission_denied()
#     unless $app->run_callbacks(
#     'cms_view_permission_filter.ajaxrating_vote',
#     $app, $id, $obj_promise );
sub can_view_vote {
    my ( $cb, $app, $id, $obj ) = @_;
    return 1;
}

# MT->run_callbacks( 'cms_pre_load_filtered_list.ajaxrating_vote',
#     $app, $filter, \%count_options, \@cols );
sub pre_load_filtered_list_vote {
    my ( $cb, $app, $filter, $options, $cols ) = @_;
}

# MT->run_callbacks( 'cms_filtered_list_param.ajaxrating_vote', $app, \%res, $objs );
sub filtered_list_param_vote {
    my ( $cb, $app, $res, $objs ) = @_;
    # return ignored
}

# $app->run_callbacks( 'cms_delete_permission_filter.ajaxrating_vote',
#     $app, $id, $vote )
#     || return $app->permission_denied();
# For the AddVote app, $id will be undef and $obj will be the vote $obj
sub can_delete_vote {
    my ( $cb, $app, $id, $obj ) = @_;

    check_request_method( $app ) or return;

    # CHECK OBJECT TYPE IF CONFIGURED TO DO SO
    my $scope    = 'blog:'.$app->param('blog_id');
    my $config   = AjaxRating->plugin->get_config_hash( $scope );
    my $obj_type = $app->param('obj_type');
    ### FIXME Should be able to use check_object_type here
    return $app->error( 'Invalid object type.')
        if $config->{ratingl} and ! grep { $obj_type eq $_ } qw( entry blog );

    ### ONLY VOTER OR SYSADMIN CAN REMOVE VOTE
    my $user = try { $app->user } catch { MT->model('user')->anonymous };
    unless ( $user->is_superuser ) {
        if (   $user->is_anonymous
            || $user->id != ( $app->param('voter_id') || 0 )) {
            return $app->error(
                'You do not have permission to remove this vote', 401 );
        }
    }
    return 1;
}


# $app->run_callbacks( 'cms_post_delete.' . $type, $app, $obj );
sub post_delete_vote {
    my ( $cb, $app, $obj ) = @_;
    # return ignored
}

sub check_request_method {
    my ( $app ) = @_;
    my $method = try { $app->request_method() } or return 1;
    return $method eq 'POST'
        || $app->error( 'Invalid request, must use POST.');
}


1;

__END__
