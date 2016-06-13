package AjaxRating::App::AddVote;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum

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
    $app->param('voter', $voter );

    my $vote  = $app->model('ajaxrating_vote')->new;
    $vote->set_values({
        ip       => $app->remote_ip         || '',
        blog_id  => $app->param('blog_id')  || 0,
        obj_type => $app->param('obj_type') || undef,
        obj_id   => $app->param('obj_id')   || undef,
        score    => $app->param('r')        || undef,
        $voter ? ( voter_id => $voter->id ) : (),
    });

    unless ( $voter && $voter->is_superuser ) {
        return $app->permission_denied() unless
            $app->run_callbacks( 'cms_save_permission_filter.ajaxrating_vote',
                                 $app, undef, $vote );
    }

    $app->run_callbacks( 'cms_save_filter.ajaxrating_vote', $app, $vote )
        or return $app->_send_error;

    $app->run_callbacks( 'cms_pre_save.ajaxrating_vote', $app, $vote )
        or return $app->_send_error( "Save failed: ". $app->errstr );

    $vote->save
        or return $app->_send_error("Saving vote failed: ". $vote->errstr );

    $app->run_callbacks( 'cms_post_save.ajaxrating_vote', $app, $vote );

    return $app->send_response( $vote );
}

sub unvote {
    my $app    = shift;
    my $format = $app->param('format') || 'text';

    my $voter = $app->get_voter()
        or return $app->_send_error( 'Not logged in.');
    $app->param( 'voter', $voter );

    my $vote = $app->model('ajaxrating_vote')->load({
        voter_id => $voter->id,
        obj_type => $app->param('obj_type'),
        obj_id   => $app->param('obj_id'),
    }) or return $app->_send_error( 'Vote not found' );

    unless ( $voter && $voter->is_superuser ) {
        return $app->permission_denied() unless
        $app->run_callbacks( 'cms_delete_permission_filter.ajaxrating_vote',
                             $app, undef, $vote );
    }

    $vote->remove
        or return $app->_send_error( 'Vote deletion failed: '.$vote->errstr );

    $app->run_callbacks( 'cms_post_delete.ajaxrating_vote', $app, $vote );

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
