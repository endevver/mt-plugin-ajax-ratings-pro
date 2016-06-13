package AjaxRating::Object::VoteSummary;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use YAML::Tiny;
use Try::Tiny;
use Carp            qw( carp croak );
use Scalar::Util    qw( looks_like_number blessed );
use List::MoreUtils qw( part first_value first_result );
use AjaxRating::Util qw( reporter );

use parent qw( AjaxRating::Object );

__PACKAGE__->install_properties({
    column_defs => {
        'id'          => 'integer not null auto_increment',
        'blog_id'     => 'integer default 0',
        'obj_type'    => 'string(50) not null',
        'obj_id'      => 'string(255) default 0',
        'author_id'   => 'integer default 0',
        'vote_count'  => 'integer default 0',
        'total_score' => 'integer default 0',
        'avg_score'   => 'float default 0',
        'vote_dist'   => 'text',
    },
    defaults    => {
        obj_type  => 'entry',
        vote_dist => '',
        map { $_ => 0 } qw( blog_id  vote_count   author_id
                            obj_id   total_score  avg_score ),
    },
    indexes     => {
        map { $_ => 1 } qw( blog_id   total_score  avg_score  obj_id
                            obj_type  author_id    vote_count       ),
    },
    audit       => 1,
    datasource  => 'ar_votesumm',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Vote Summary");
}

sub class_label_plural {
    MT->translate("Vote Summaries");
}

sub list_properties {
    my $self  = shift || __PACKAGE__;
    my $class = blessed($self);
    $class    = __PACKAGE__ if ! $class or $class eq 'MT::Plugin';
    $self     = $self->new() unless blessed($self);
    return {
        %{ $self->SUPER::list_properties()         },
        %{ $self->SUPER::summary_list_properties() },

        vote_distribution => {
            label   => 'Vote Distribution',
            order   => 400,
            display => 'optional',
            col     => 'vote_dist',
            html    => sub {
                my ( $prop, $obj, $app, $opts ) = @_;
                # Read the saved YAML vote_distribution, and convert it into a
                # hash.
                my $yaml = YAML::Tiny->read_string( $obj->vote_dist );
                # Load the entry_max_points or comment_max_points config setting
                # (depending upon the object type), or just fall back to the
                # value 5. 5 is used as the default for the max points, so it's
                # a safe guess that it's good to use.
                my $plugin = MT->component('ajaxrating');
                my $max_points = $plugin->get_config_value(
                    $obj->obj_type.'_max_points',
                    'blog:'.$obj->blog_id
                ) || 5;

                # Make sure that all possible scores have been marked--at least
                # with a 0. The default value is set here (as opposed to in the
                # foreach that outputs the values) so that different types of
                # raters (which may have positive or negative values) don't get
                # confused.
                my $count = 1;
                while ( $count <= $max_points ) {
                    $yaml->[0]->{$count} = '0' if !$yaml->[0]->{$count};
                    $count++;
                }

                # Put together the votes and scores to create a list:
                #     Score: 1; Votes: 3
                #     Score: 2; Votes: 1
                #     Score: 3; Votes: 7
                #     Score: 4; Votes: 12
                #     Score: 5; Votes: 9
                my $out = '';
                foreach my $score ( sort {$a <=> $b} keys %{$yaml->[0]} ) {
                    $out .= 'Score: ' . $score
                        . '; Votes: ' . $yaml->[0]->{$score}
                        . '<br />';
                }
                return $out;
            },
        },
    };
}

sub votes {
    my @objs = MT->model('ajaxrating_vote')->load( shift()->object_terms, @_ );
    return wantarray ? @objs : \@objs;
}

sub votes_iter {
    return MT->model('ajaxrating_vote')->load_iter( shift()->object_terms, @_ );
}

sub object_matches {
    my ( $self, $obj, $args ) = @_;
    my $obj_class = blessed($obj) or croak "Argument is not an object";
    my $die       = ($args ||= {})->{or_die} ? 1 : 0;

    my $rc = 0;

    if ( $obj_class =~ m/^AjaxRating::Object::(Vote(Summary)?|HotObject)$/ ) {
        my ( $obj_blog, $self_blog ) = map { $_ || 0 }
                                        $obj->blog_id, $self->blog_id;
        return 1 if $obj->obj_id   == $self->obj_id
                and $obj->obj_type eq $self->obj_type;
        $die and $die = [
            $self_blog, $self->obj_type, $self->obj_id,
            'Vote', $obj_blog, $obj->obj_type, $obj->obj_id
        ];
    }
    elsif ( $obj->isa('MT::Object') ) {
        my $self_blog    = $self->blog_id || 0;
        my $obj_blog     = $obj->has_column('blog_id') ? ($obj->blog_id||0) : 0;
        my $ar_obj_class = MT->model( $self->obj_type );
        return 1 if $obj_blog  == $self_blog
                and $obj->id   == $self->obj_id
                and $obj_class eq $ar_obj_class;
        $die and $die = [
            $self_blog, $self->obj_type, $self->obj_id,
            'Object', $obj_blog, $obj->datasource, $obj->id
        ];
    }
    else { die "Unknown argument in ".ref($self).'::object_matches: '.$obj }

    return 0 unless $die;

    die sprintf(
        'Object mismatch for %d:%s:%d votesummary: %s is for %d:%s:%d', @$die );
}

sub add_vote {
    my ( $self, $vote ) = @_;

    try { $self->object_matches( $vote, { or_die => 1 } ) } catch { croak $_ };

    $self->{__vote} = $vote;

    unless ( $self->id ) {
        if ( my $object = $self->object() ) {
            my $user_col = first_value { $object->has_column($_) }
                qw( author_id commenter_id created_by );
            $self->author_id( $object->$user_col ) if $user_col;
        }
    }

    $self->adjust_for_vote({ score => $vote->score, add => 1 });
}


sub remove_vote {
    my ( $self, $vote ) = @_;

    $self->{__vote} = $vote;

    try { $self->object_matches( $vote, { or_die => 1 } ) } catch { croak $_ };

    croak 'Unhandled exception: remove_vote from unsaved '.ref($self).' object'
        unless $self->object_is_stored;

    $self->adjust_for_vote({ vote => $vote, remove => 1 });
}

sub adjust_for_vote {
    my ( $self, $args ) = @_;

    croak( "Bad argument: $args" ) unless 'HASH' eq ref $args;

    if ( my $vote = $args->{vote} ) {
        try   { $self->object_matches( $vote, { or_die => 1 } ) }
        catch { croak $_ };
        $args->{score} //= $vote->score;
    }

    my $count = ( $self->vote_count  || 0 ) + ( $args->{remove}  ? -1 : 1 );
    if ( $count < 1 ) {
        $self->remove;
        return;
    }

    my $score = ( $self->total_score || 0 )
              + ( $args->{score} * ( $args->{remove} ? -1 : 1 ));
    $score = 0 if $score < 0;

    # Update the VoteSummary with details of this vote.
    $self->vote_count( $count );
    $self->total_score( $score );
    $self->avg_score( sprintf("%.1f", $self->total_score / $self->vote_count) );

    # Update the voting distribution, which makes it easy to output
    # "X Stars has received Y votes"
    # Supply an empty string if there's no existing vote distribution --
    # which is true if this is a new vote summary object.
    my $yaml = $self->compile_vote_dist();

    # Increase the vote tally for this score by 1, output and save the string
    $yaml->[0]->{$args->{score}} += ( $args->{remove} ? -1 : 1 );
    $self->vote_dist( $yaml->write_string() );

    $self->save or die $self->errstr;
}

# TODO vote_dist should be a translated field; callbacks should automatically handle the serialization and unserialization
sub compile_vote_dist {
    my $self = shift;
    unless ( $self->vote_dist ) {
        $self = $self->rebuild_votesummary_record();
    }
    return YAML::Tiny->read_string( $self->vote_dist || '' )
        || YAML::Tiny->new;
}

sub pre_save {
    my ( $cb, $obj, $obj_orig ) = @_;
    $obj->SUPER::pre_save(@_);
}

sub post_save {
    # reporter(@_)
}

sub post_remove {
    # reporter(@_)
}


1;

__END__

sub remove_scores {
    my $class = shift;
    require MT::ObjectScore;
    my ( $terms, $args ) = @_;
    $args = {%$args} if $args;    # copy so we can alter
    my $offset = 0;
    $args ||= {};
    $args->{fetchonly} = ['id'];
    $args->{join}      = [
        'MT::ObjectScore', 'object_id',
        { object_ds => $class->datasource }
    ];
    $args->{no_triggers} = 1;
    $args->{limit}       = 50;

    while ( $offset >= 0 ) {
        $args->{offset} = $offset;
        if ( my @list = $class->load( $terms, $args ) ) {
            my @ids = map { $_->id } @list;
            MT::ObjectScore->driver->direct_remove( 'MT::ObjectScore',
                { object_ds => $class->datasource, 'object_id' => \@ids } );
            if ( scalar @list == 50 ) {
                $offset += 50;
            }
            else {
                $offset = -1;    # break loop
            }
        }
        else {
            $offset = -1;
        }
    }
    return 1;
}

