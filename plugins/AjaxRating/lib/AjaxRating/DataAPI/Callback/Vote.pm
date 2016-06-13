package AjaxRating::DataAPI::Callback::Vote;

use strict;
use warnings;
use AjaxRating::CMS;

# data_api_save_permission_filter.ajaxrating_vote
#    A permission-filter callback.
#    Returns 1 if current user can save this object.
# 1st callback called by MT::DataAPI::Endpoint::Common::save_object
# Never called if the current user is superuser
# If returns false, $app gets empty list and $app->error(403)
sub can_save {
    # run_permission_filter( $app, 'data_api_save_permission_filter',
    #     $type, $obj->id, $obj, $original )
    #     or return;
    my ( $cb, $app, $obj_id, $obj, $original ) = @_;
    AjaxRating::CMS::can_save_vote(@_) or return;
    return 1; # else $app->error(403)
}

# data_api_save_filter.ajaxrating_vote
#     A filter callback.
#     Returns 1 if the MT can save this object.
# 2nd callback called by MT::DataAPI::Endpoint::Common::save_object
sub save_filter {
    # $app->run_callbacks( 'data_api_save_filter.' . $type,
    #     $app, $obj, $original )
    #     or return $app->error( $app->errstr, 409 );
    my ( $cb, $app, $obj, $orig ) = @_;
    AjaxRating::CMS::save_filter_vote(@_) or return;
    return 1; # Else $app->error( $app->errstr, 409 );
}

# data_api_pre_save.ajaxrating_vote
#     A filter callback.
#     Returns 1 if the MT can save this object.
# 3rd callback called by MT::DataAPI::Endpoint::Common::save_object
sub pre_save {
    # $app->run_callbacks( 'data_api_pre_save.' . $type, $app, $obj, $original )
    #     or return $app->error(
    #     $app->translate( "Save failed: [_1]", $app->errstr ), 409 );
    my ( $cb, $app, $obj, $orig ) = @_;
    AjaxRating::CMS::pre_save_vote(@_) or return;
    return 1; # Else $app->error( "Save failed: ".$app->errstr, 409 );
}

# data_api_post_save.ajaxrating_vote
#     A post-save callback.
# Last callback called by MT::DataAPI::Endpoint::Common::save_object
sub post_save {
    # $app->run_callbacks( 'data_api_post_save.' . $type,
    #     $app, $obj, $original );
    my ( $cb, $app, $obj, $orig ) = @_;
    AjaxRating::CMS::post_save_vote(@_);
    # return ignored
}

# data_api_list_permission_filter.ajaxrating_vote
#     A permission-filter callback.
#     Returns 1 if current user can retrieve a list of this $ds.
# 1st callback called by MT::DataAPI::Endpoint::Common::filtered_list
# Never called if the current user is superuser
# If returns false, $app gets empty list and $app->error(403)
sub can_view {
    # run_permission_filter( $app, 'data_api_list_permission_filter',
    #     $ds, $terms, $args, $options )
    #     or return;
    my ( $cb, $app, $ds, $terms, $args, $options ) = @_;
    AjaxRating::CMS::can_view_vote(@_) or return;
    return 1;   # Else $app->error(403)
}

# data_api_pre_load_filtered_list.ajaxrating_vote
# 2nd callback called by MT::DataAPI::Endpoint::Common::filtered_list
# Called just before $filter->count_objects
# Then again before $filter->load_objects
sub pre_load_filtered_list {
    # MT->run_callbacks( 'data_api_pre_load_filtered_list.' . $ds,
    #     $app, $filter, \%count_options, \@cols );
    my ( $cb, $app, $filter, $options, $cols ) = @_;  # $cols is an arrayref
    AjaxRating::CMS::pre_load_filtered_list_vote(@_);
    # return ignored
}

# data_api_delete_permission_filter.ajaxrating_vote
#     A permission-filter callback.
#     Returns 1 if current user can remove this object.
# Initial callback called by MT::DataAPI::Endpoint::Common::remove_object
# Never called if the current user is superuser
# If returns false, $app gets empty list and $app->error(403)
sub can_delete {
    # run_permission_filter( $app, 'data_api_delete_permission_filter',
    #     $type, $obj )
    #     or return;
    my ( $cb, $app, $obj ) = @_;
    AjaxRating::CMS::can_delete_vote(@_) or return;
    return 1;  # Else $app->error(403)
}

# data_api_post_delete.ajaxrating_vote
#     A post-remove callback.
# Final callback called by MT::DataAPI::Endpoint::Common::remove_object
sub post_delete {
    # $app->run_callbacks( 'data_api_post_delete.' . $type, $app, $obj );
    my ( $cb, $app, $obj ) = @_;
    AjaxRating::CMS::post_delete_vote(@_);
    # return ignored
}

1;

__END__
