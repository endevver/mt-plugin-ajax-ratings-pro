package AjaxRating::VoteSummary;
use strict;
use warnings;
use YAML::Tiny;
use Carp qw( croak );

use MT::Object;
@AjaxRating::VoteSummary::ISA = qw(MT::Object);
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
    indexes => {
        blog_id => 1,
        obj_type => 1,
        obj_id => 1,
        author_id => 1,
        vote_count => 1,
        total_score => 1,
        avg_score => 1
    },
    audit => 1,
    datasource => 'ar_votesumm',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Vote Summary");
}

sub class_label_plural {
    MT->translate("Vote Summaries");
}

# Remove this entry and all of its votes from the DB
# Depends on MySQL.
sub purge {
    my ($self) = @_;
    # Clean up the votes. Not fully portable but much faster.
    # Note that any delete object callbacks on an EP::Vote object ARE NOT INVOKED.
    # Let me repeat that:
    # !! DELETE OBJECT CALLBACKS ARE NOT INVOKED WHEN THE VOTE OBJECTS ARE REMOVED !!
    # This presumably why there is no direct support for this kind of thing (although
    # one wonders why it couldn't be done in a bulkier fashion internally, e.g.
    # load up 1000 objects or so at a time, invoke the callbacks, then delete them
    # in bulk, yielding a 500:1 reduction in DB calls)
    my $db = MT::Object->driver();
    $db->sql(
        'DELETE FROM mt_' . AjaxRating::Vote->datasource()
        . ' WHERE ' . AjaxRating::Vote->datasource()
        . '_EntryID=' . $self->id() . ';'
    );
    $self->remove(); # remove this object from the DB
}

sub list_properties {
    require AjaxRating::CMS;
    return {
        id => {
            label   => 'ID',
            display => 'optional',
            order   => 1,
            auto    => 1,
        },
        blog_name => {
            base  => '__common.blog_name',
            label => sub {
                MT->app->blog
                    ? MT->translate('Blog Name')
                    : MT->translate('Website/Blog Name');
            },
            display   => 'default',
            site_name => sub { MT->app->blog ? 0 : 1 },
            order     => 99,
        },
        obj_type => {
            label   => 'Target Object Type',
            order   => 100,
            display => 'default',
            auto    => 1,
        },
        obj_id => {
            base    => '__virtual.integer',
            label   => 'Target Object ID',
            order   => 101,
            display => 'optional',
            col     => 'obj_id',
            auto    => 1,
        },
        object => {
            label   => 'Target Object',
            order   => 102,
            display => 'default',
            html    => \&AjaxRating::CMS::list_prop_object_content,
        },
        average_score => {
            base    => '__virtual.float',
            label   => 'Average Score',
            order   => 200,
            display => 'default',
            col     => 'avg_score',
        },
        total_score => {
            base    => '__virtual.float',
            label   => 'Total Score',
            order   => 201,
            display => 'optional',
            col     => 'total_score',
        },
        number_of_votes => {
            base    => '__virtual.integer',
            label   => 'Number of Votes',
            order   => 300,
            display => 'default',
            col     => 'vote_count',
            html    => sub {
                my ( $prop, $obj, $app, $opts ) = @_;

                my $url = $app->uri(
                    mode =>'list',
                    args => {
                        '_type'      => 'ajaxrating_vote',
                        'filter_key' => '_obj_id',
                        'filter_val' => $obj->obj_type . ':' . $obj->obj_id,
                        'blog_id'    => $obj->blog_id
                    },
                );

                return '<a href="' . $url . '" title="View details of all votes">'
                    . $obj->vote_count . '</a>';
            },
        },
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
        created_on => {
            base    => '__virtual.created_on',
            order   => 810,
            display => 'default',
        },
        modified_on => {
            base    => '__virtual.modified_on',
            order   => 811,
            display => 'default',
        },
    };
}

sub add_vote {
    my ( $obj, $vote ) = @_;

    if ( $obj->id ) {
        $obj->modified_by( $vote->voter_id ) if $vote->voter_id;
    }
    else {
        $obj->blog_id( $vote->blog_id ) if $vote->blog_id;
        if ( $vote->voter_id ) {
            $obj->author_id( $vote->voter_id );
            $obj->created_by( $vote->voter_id );
        }
    }
    $obj->adjust_for_vote({ score => $vote->score, add => 1 });
}

sub remove_vote {
    my ( $obj, $vote ) = @_;
    $obj->adjust_for_vote({ score => $vote->score, remove => 1 });
}

sub adjust_for_vote {
    my ( $obj, $args ) = @_;

    croak( "Bad argument: $args" ) unless 'HASH' eq ref $args;

    my $count = ( $obj->vote_count  || 0 ) + ( $args->{remove}  ? -1 : 1 );
    if ( $count < 1 ) {
        $obj->vote_count(0);
        $obj->total_score(0);
        $obj->avg_score(0);
        $obj->vote_dist('');
        $obj->remove;
        return;
    }

    my $score = ( $obj->total_score || 0 )
              + ( $args->{score} * ( $args->{remove} ? -1 : 1 ));
    $score = 0 if $score < 0;

    # Update the VoteSummary with details of this vote.
    $obj->vote_count( $count );
    $obj->total_score( $score );
    $obj->avg_score( sprintf("%.1f", $obj->total_score / $obj->vote_count) );

    # Update the voting distribution, which makes it easy to output
    # "X Stars has received Y votes"
    # Supply an empty string if there's no existing vote distribution --
    # which is true if this is a new vote summary object.
    my $yaml = YAML::Tiny->read_string( $obj->vote_dist || '' )
            || YAML::Tiny->new;     # No previously-saved data.
    # Increase the vote tally for this score by 1, output and save the string
    $yaml->[0]->{$args->{score}} += ( $args->{remove} ? -1 : 1 );
    $obj->vote_dist( $yaml->write_string() );

    # Update the the summary's modified on timestamp.
    my ( $s, $m, $h, $d, $mo, $y ) = localtime(time);
    my $mod_time = sprintf( "%04d%02d%02d%02d%02d%02d",
        1900 + $y, $mo + 1, $d, $h, $m, $s );
    $obj->modified_on( $mod_time );

    $obj->save or die $obj->errstr;
}

1;
