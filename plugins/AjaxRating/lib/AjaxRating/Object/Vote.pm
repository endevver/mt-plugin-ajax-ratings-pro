package AjaxRating::Object::Vote;

### FIXME Check for previous voter upon save

use strict;
use warnings;
use 5.0101;
use Carp         qw( croak );
use Scalar::Util qw( blessed looks_like_number );

use AjaxRating::Object;
@AjaxRating::Object::Vote::ISA = qw( AjaxRating::Object );

__PACKAGE__->install_properties({
    column_defs => {
        'id'       => 'integer not null auto_increment',
        'blog_id'  => 'integer default 0',
        'voter_id' => 'integer default 0',
        'obj_type' => 'string(50) not null',
        'obj_id'   => 'string(255) default 0',
        'score'    => 'integer default 0',
        'ip'       => 'string(15)'
    },
    defaults    => {
        obj_type   => 'entry',
        ip         => '',
        map { $_ => 0 } qw( blog_id voter_id obj_id score )
    },
    indexes     => {
        map { $_ => 1 } qw( blog_id voter_id obj_id obj_type ip ),
    },
    audit       => 1,
    datasource  => 'ar_vote',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Vote");
}

sub class_label_plural {
    MT->translate("Votes");
}

# Properties for the listing framework, to show the vote activity log.
sub list_properties {
    my $self  = shift || __PACKAGE__;
    my $class = blessed($self);
    $class    = __PACKAGE__ if ! $class or $class eq 'MT::Plugin';
    $self     = $self->new() unless blessed($self);
    return {
        %{ $self->SUPER::list_properties() },

        score => {
            base    => '__virtual.float',
            label   => 'Score',
            order   => 200,
            display => 'default',
            col     => 'score',
        },
    };
}

sub voter {
    my $self    = shift;
    state $User = MT->model('user');

    if ( my $user = shift ) {
        if ( looks_like_number($user) ) {
            $user = $self->{__voter} = $User->load( $user );
        }
        elsif ( blessed($user) && $user->isa( $User ) ) {
            $self->{__voter} = $user;
        }
        else { croak "Unknown voter argument: ".$user }

        $self->voter_id( $user ? $user->id : undef );
    }

    $self->{__voter} ||= $User->load( $self->voter_id )
        if $self->voter_id;
}

sub votesummary {
    my $self  = shift;
    MT->model('ajaxrating_votesummary')->get_by_key( $self->object_terms );
}

## subnet will return the first 3 sections of an IP address.
## If passed 24.123.2.45, it will return 24.123.2
sub subnet {
    my $vote = shift;
    my $ip = $vote->ip;
    my @parts = split(/\./,$ip);
    my $subnet = $parts[0] . "." . $parts[1] . "." . $parts[2];
    return $subnet;
}

sub pre_save {
    my ( $cb, $obj, $obj_orig ) = @_;

    $obj->SUPER::pre_save(@_);

    if ( $obj->id ) {
        # This vote was previously counted in the votesummary so remove it first since it will be added in the post_save.
        my $vsumm = $obj->votesummary();
        $vsumm->remove_vote( $obj ) if $vsumm->id;
    }

    return 1;
}

sub post_save {
    my ( $cb, $obj, $obj_orig ) = @_;

    # Update the Vote Summary. The summary is used because it will let
    # publishing happen faster (loading one summary row to publish results
    # is faster than loading many AjaxRating::Object::Vote records).
    $obj->votesummary->add_vote( $obj );

    # Now that the vote has been recorded, rebuild the required pages.
    $obj->rebuild_vote_object();

    return 1;
}

sub post_remove {
    my ( $cb, $obj ) = @_;

    my $vsumm = $obj->votesummary;
    $vsumm->remove_vote( $obj ) if $vsumm->id;

    # Now that the vote has been recorded, rebuild the required pages.
    $obj->rebuild_vote_object();

    return 1;
}

sub remove_filter {
    my ( $cb, $app, $obj, $obj_orig ) = @_;

    return $app->error( 'Invalid request, must use POST.')
        if $app->can('request_method')
            and $app->request_method() ne 'POST';

    my $scope = 'blog:'.$app->param('blog_id');
    my $config = $app->component('ajaxrating')->get_config_hash( $scope );
    my $obj_type = $app->param('obj_type');
    return $app->error( 'Invalid object type.')
        if $config->{ratingl} and ! grep { $obj_type eq $_ } qw( entry blog );

    if ( ! $app->user or $app->user->id != ($app->param('voter_id')||0) ) {
        return $app->error(
            'You do not have permission to remove this vote', 401 );
    }
}

sub save_filter {
    my ( $cb, $app, $obj, $obj_orig ) = @_;

    return $app->error( 'Invalid request, must use POST.')
        if $app->can('request_method')
            and $app->request_method() ne 'POST';

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
    my %terms = %{ $obj->object_terms };

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

sub rebuild_vote_object {
    my ( $self, $rebuild ) = @_;
    my $app = MT->instance;

    unless ( $rebuild ) {
        my $plugin = MT->instance->component('ajaxrating');
        my $config = $plugin->get_config_hash('blog:'.$self->blog_id);
        $rebuild = $config->{rebuild} or return;
    }

    require MT::Util;
    MT::Util::start_background_task(sub {
        my $entry;
        if ( grep { $self->obj_type eq $_ } qw( entry page topic ) ) {
            $entry = MT->model('entry')->load( $self->obj_id )
                or warn sprintf '%s ID %s not found for rebuilding',
                        $self->obj_type, $self->obj_id;
        }
        elsif ( $self->obj_type eq 'comment' ) {
            my $comment = $app->model('comment')->load( $self->obj_id );
            $entry      = $comment->entry;
        }
        elsif ( $self->obj_type eq 'ping' ) {
            my $ping = $app->model('tbping')->load( $self->obj_id );
            $entry   = $ping->entry;
        }

        if ( $entry && $rebuild == 1 ) {
            $app->publisher->_rebuild_entry_archive_type(
                Entry => $entry, ArchiveType => 'Individual',
            );
        }
        elsif ( $self->obj_type eq "category" and $rebuild == 1 ) {
            my $category = $app->mode('category')->load( $self->obj_id );
            $app->publisher->_rebuild_entry_archive_type(
                Category => $category, ArchiveType => 'Category',
            );
        }
        elsif ( $entry && $rebuild == 2 ) {
            $app->rebuild_entry(   Entry  => $entry   );
            $app->rebuild_indexes( BlogID => $self->blog_id );
        }
        elsif ( $rebuild == 3 ) {
            $app->rebuild_indexes( BlogID => $self->blog_id );
        }
        # else {
        #     warn "Nothing found to rebuild after rating";
        # }
    });  ### end of background task
}

1;

__END__
