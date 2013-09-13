package AjaxRating::GetVotes;

use strict;
use warnings;

use AjaxRating::App;
@AjaxRating::GetVotes::ISA = qw( AjaxRating::App );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        default   => \&get_votes,
        get_votes => \&get_votes,
    );
    $app;
}

# Grab the vote summary record for an object ID/type.
sub get_votes {
    my $app    = shift;
    my $q      = $app->can('query') ? $app->query : $app->param;
    my $format = $q->param('format') || 'text';
    my ( $obj_type, $obj_id, $blog_id )
        = map { $q->param($_) } qw( obj_type obj_id blog_id );

    return $app->_send_error( $format,
        "Required parameters blog_id, obj_type, and obj_id not found.")
        if !$blog_id || !$obj_type || !$obj_id;

    my $plugin = $app->component('ajaxrating');
    my $config = $plugin->get_config_hash('blog:'.$blog_id);

    return $app->_send_error( $format, "Invalid object type specified.")
        if ( $config->{ratingl}
        && ( $obj_type ne 'entry')
        && ( $obj_type ne 'blog')  );

    require AjaxRating::VoteSummary;
    my $votesummary = AjaxRating::VoteSummary->get_by_key({
        obj_type => $obj_type,
        obj_id   => $obj_id,
    });

    # If there is no record found that's not necessarily a problem: there may
    # simply be no votes yet, and therefore no summary record to load. So, just
    # report "0" for the values, because that is effectively true.
    unless ( $votesummary->id ) {
        $votesummary->vote_count(  0 );
        $votesummary->total_score( 0 );
    }

    if ($format eq 'json') {
        return $app->_send_json_response({
            status      => "OK",
            message     => "Vote summary retreived.",
            obj_type    => $votesummary->obj_type,
            obj_id      => $votesummary->obj_id,
            total_score => $votesummary->total_score,
            vote_count  => $votesummary->vote_count,
        });
    } else {
        # Return a string, which uses "||" as separators. The returned
        # string is parsed by javascript -- splitting the "||" to create an
        # array of values.
        return "OK||" . $votesummary->obj_type
            . "||" . $votesummary->obj_id
            . "||" . $votesummary->total_score
            . "||" . $votesummary->vote_count;
    }
}

1;
