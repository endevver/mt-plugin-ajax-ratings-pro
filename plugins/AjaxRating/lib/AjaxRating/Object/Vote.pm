package AjaxRating::Object::Vote;

### FIXME Check for previous voter upon save

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use Carp         qw( croak );
use Scalar::Util qw( blessed looks_like_number );

use parent qw( AjaxRating::Object );

__PACKAGE__->install_properties({
    column_defs => {
        'id'       => 'integer not null auto_increment',
        'blog_id'  => 'integer default 0',
        'voter_id' => 'integer default 0',
        'obj_type' => 'string(50) not null',
        'obj_id'   => 'string(255) default 0', ### FIXME should be not null
        'score'    => 'integer default 0',     ### FIXME should be not null
        'ip'       => 'string(15)',            ### FIXME should be default ""
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

sub required_fields { qw( obj_type obj_id score ) }

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
    my $voter;

    if ( my $voter = shift ) {
        if ( looks_like_number($voter) ) {
            $voter = $self->{__voter} = $User->load( $voter );
        }
        elsif ( blessed($voter) && $voter->isa( $User ) ) {
            $self->{__voter} = $voter;
        }
        else {
            croak "Unknown voter argument: ".$voter
        }

        $self->voter_id( try { $voter->id } || undef );
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

##########################################
######## OBJECT CALLBACK HANDLERS ########
##########################################

sub post_remove {
    my ( $cb, $obj ) = @_;

    # Remove the vote from the votesummary and rebuild the required pages
    my $vsumm = $obj->votesummary;
    $vsumm->remove_vote( $obj ) if $vsumm->id;
    $obj->rebuild_vote_object();

    return 1;
}

sub pre_save {
    my ( $cb, $obj, $obj_orig ) = @_;

    $obj->SUPER::pre_save(@_) or return;

    my $plugin  = AjaxRating->plugin;
    my $blog_id = $obj->blog_id;
    my $config  = {
        %{ $plugin->get_config_hash('system') || {} },
        $blog_id ? %{ $plugin->get_config_hash("blog:$blog_id") || {} } : ()
    };

    return $obj->check_required_fields
        && $obj->check_score_range( $config )
        && $obj->check_object_type( $config )
        && $obj->check_duplicate( $config )
            || MT->instance->error( $obj->errstr );
    return 1;
}

sub post_save {
    my ( $cb, $obj, $obj_orig ) = @_;

    unless ( delete $obj->{__resave} ) {
        # Update the Vote Summary and rebuild the required pages
        $obj->votesummary->add_vote( $obj );
        $obj->rebuild_vote_object();
    }
}

##################################
######## CALLBACK HELPERS ########
##################################

sub check_required_fields {
    my ( $obj )  = @_;
    my @missing  = grep { ! $obj->$_ } $obj->required_fields;
    return ! scalar( @missing )
        || $obj->error( 'Vote not saved due to missing fields: '
                      . join(', ', @missing) );
}

### FIXME Should there be a default max score? If so, why 10?
### FIXME Should 0 or a negative score be allowed?
###       If so, votesummary arithmetic should be validated throughout
sub check_score_range {
    my ( $obj, $config ) = @_;
    my $type          = $obj->obj_type || '';
    my %defs          = ( min => 0, max => 10 ); # DEFAULTS. See above comment
    my ( $min, $max ) = map { $config->{"${type}_${_}_points"} || $defs{$_} }
                           qw( min max );
    return ( $obj->score <= $max ) && ( $obj->score >= $min )
        || $obj->error( "Score must be between $min and $max, inclusive." )
}

sub check_object_type {
    my ( $obj, $config ) = @_;
    my $type             = $obj->obj_type // 'UNDEFINED';
    return $obj->error( 'Invalid object type specified: '.$type )
        if $config->{ratingl} and ! grep { $type eq $_ } qw( entry blog );
    return 1;
}

sub check_duplicate {
    my $obj = shift;
    $obj->check_dupe_by_voter( @_ ) && $obj->check_dupe_by_ip( @_ );
}

### DUPLICATE VOTE CHECK - USER
# Return error if vote exists from current logged-in user, if exists
sub check_dupe_by_voter {
    my $obj = shift;
    my $id = $obj->voter_id
        or return 1; # PASS if no voter_id to check
    return ! ref($obj)->exist({ voter_id => $id, %{ $obj->object_terms } })
        || $obj->error( 'You have already voted on '
                        . $obj->obj_type. ' ID '.$obj->obj_id );
}

### OR DUPLICATE VOTE CHECK - IP ADDRESS
# If the vote has an IP and IP address checking is enabled, return an error if
# we already have a vote from that IP address. This check is only
# performed if we do not have an active user (see check_dupe_by_voter)
sub check_dupe_by_ip {
    my ( $obj, $config ) = @_;
    return 1 unless $obj->ip and $config->{enable_ip_checking};
    return ! ref($obj)->exist({ %{ $obj->object_terms }, ip => $obj->ip })
        || $obj->error( 'Your IP address has already voted on this item.');
}

sub rebuild_vote_object {
    my ( $self, $rebuild ) = @_;
    $rebuild ||= do {
        AjaxRating->plugin->get_config_hash('blog:'.$self->blog_id)->{rebuild}
    };
    return 1 unless $rebuild;

    require MT::Util;
    MT::Util::start_background_task(sub {
        my $app = MT->instance;
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
    return 1;
}

1;

__END__
