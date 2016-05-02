package AjaxRating::App::GetVotes;

use strict;
use warnings;
use AjaxRating::App;
@AjaxRating::App::GetVotes::ISA = qw( AjaxRating::App );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods( default => \&get_votes, get_votes => \&get_votes );
    $app;
}

# Grab the vote summary record for an object ID/type.
sub get_votes {
    my $app      = shift;

    my @required = qw( obj_type obj_id blog_id );
    my @missing  = grep { ! $app->param($_) } @required;
    if ( @missing ) {
        my $missing = join(', ', @missing );
        # p %{{ $app->param_hash }};
        return $app->_send_error("Required parameters not found: $missing");
    }

    my $blog_id  = $app->param('blog_id');
    my $obj_type = $app->param('obj_type');
    my $scope    = 'blog:'.$blog_id;
    my $config   = $app->component('ajaxrating')->get_config_hash( $scope );
    return $app->_send_error( 'Invalid object type: '.$obj_type)
        if $config->{ratingl} and ! grep { $obj_type eq $_ } qw( entry blog );

    my @result;

    # $obj_ids could be a comma-separated list of object IDs to retrieve.
    my $obj_ids = $app->param('obj_id');
    my $format  = $app->param('format') || 'text';
    foreach my $obj_id ( split(/\s*,\s*/, $obj_ids) ) {

        my $vsumm = $app->model('ajaxrating_votesummary')->get_by_key({
            obj_type => $obj_type, obj_id => $obj_id,
            $blog_id ? ( blog_id => $blog_id ) : ()
        });

        # If there is no record found that's not necessarily a problem: there
        # may simply be no votes yet, and therefore no summary record to load.
        # So, just report "0" for the values, because that is effectively true.

        if ($format eq 'json') {
            push @result, {
                status      => "OK",
                message     => "Vote summary retreived.",
                map { $_ => $vsumm->$_ || 0 }
                    qw( obj_type obj_id total_score vote_count )
            };
        } else {
            # Return a string, which uses "||" as separators. The returned
            # string is parsed by javascript -- splitting the "||" to create an
            # array of values.
            push @result, join('||', 'OK', map { $vsumm->$_ || 0 }
                            qw(obj_type obj_id total_score vote_count) );
        }
    }

    if ( $format eq 'json' ) {
        # If more than one item was requested, return an array of values.
        # Legacy: return a single value, not in an array.
        return $app->json_result(
            scalar @result > 1 ? [ @result] : $result[0] );
    }
    else {
        # Return a string, which uses "||" as separators. The returned
        # string is parsed by javascript -- splitting the "||" to create an
        # array of values.
        return join(':', @result );
    }
}

1;

__END__
