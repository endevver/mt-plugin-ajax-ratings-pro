package AjaxRating::App;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use MT::App;
@AjaxRating::App::ISA = qw( MT::App );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;

    if ( my $mode = $app->can('default_mode') ) {
        $app->add_methods( default => $mode );
    }

    $app->{default_mode} = 'default';
    $app->{charset} = $app->{cfg}->PublishCharset;
    $app;
}

sub send_response {
    my ( $app, $vote, $format ) = @_;
    $format ||= $app->param('format') || 'text';

    my $vsumm = MT->model('ajaxrating_votesummary')->get_by_key(
        $vote->object_terms
    );

    if ($format eq 'json') {
        return $app->json_result({
            %{ $vsumm->object_terms },
            status      => "OK",
            message     => "Vote Successful",
            score       => $app->param('r'),
            total_score => $vsumm->total_score,
            vote_count  => $vsumm->vote_count,
        });
    } else {
        # Return a string, which uses "||" as separators. The returned
        # string is parsed by javascript -- splitting the "||" to create an
        # array of values.
        return join('||',
            'OK', $vsumm->obj_type, $vsumm->obj_id, $app->param('r'),
            $vsumm->total_score, $vsumm->vote_count );
    }
}

sub _send_error {
    my ( $app, $msg, $format ) = @_;
    $msg //= $app->errstr;
    $format ||= $app->param('format') || '';
    return $format eq 'json' ? $app->json_error( $msg ) : "ERR||$msg";
}

sub permission_denied {
    my $app = shift;
    $app->SUPER::permission_denied();
    return $app->_send_error;
}

1;
