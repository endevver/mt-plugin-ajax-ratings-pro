package AjaxRating::App::AddVote;

use strict;
use warnings;
use AjaxRating::App;
@AjaxRating::App::AddVote::ISA = qw( AjaxRating::App );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        default => \&vote,
        vote    => \&vote,         # alias for backcompat
        unvote  => \&unvote
    );
    $app;
}

sub vote {
    my $app   = shift;
    my $voter = $app->get_voter();
    my $vote  = $app->model('ajaxrating_vote')->new;
    $vote->set_values({
        ip       => $app->remote_ip || '',
        blog_id  => $app->param('blog_id'),
        obj_type => $app->param('obj_type'),
        obj_id   => $app->param('obj_id'),
        score    => $app->param('r'),
        $voter ? ( voter_id => $voter->id ) : (),
    });

    $vote->save
        or return $app->_send_error(
            $vote->errstr || 'Unknown error saving vote' );

    return $app->send_response( $vote );
}

sub unvote {
    my $app    = shift;
    my $format = $app->param('format') || 'text';

    my $voter = $app->get_voter()
        or return $app->_send_error( 'Not logged in.');

    my $vote = $app->model('ajaxrating_vote')->load({
        voter_id => $voter->id,
        obj_type => $app->param('obj_type'),
        obj_id   => $app->param('obj_id'),
    }) or return $app->_send_error( 'Vote not found' );

    $vote->remove
        or return $app->_send_error(
            $vote->errstr||'Unknown error removing vote' );

    return $app->send_response( $vote, $format );
}

sub get_voter {
    my ( $app ) = @_;
    my ( $session, $voter ) = $app->get_commenter_session;
    return $voter if $voter;

    if ( my $sid = $app->param('sid') ) {
        if ( my $sess_obj = MT->model('session')->load({ id => $sid }) ) {
            $session = $sess_obj;
            if ( my $user_id = $sess_obj->get('author_id') ) {
                $voter = MT->model('author')->load( $user_id );
            }
        }
    }
    return $voter && $voter->id ? $voter : undef;
}

1;
