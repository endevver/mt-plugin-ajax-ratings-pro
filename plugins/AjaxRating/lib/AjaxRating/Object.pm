package AjaxRating::Object {

    use strict;
    use warnings;
    use 5.0101;
    use Try::Tiny;
    use Carp            qw( croak );
    use List::MoreUtils qw( first_value );

    use MT::Object;
    @AjaxRating::Object::ISA = qw( MT::Object );

    use AjaxRating::Util qw( sync_author_fields );

    sub list_properties {
        require AjaxRating::CMS;
        return +{
            id => {
                label   => 'ID',
                display => 'optional',
                order   => 1,
                auto    => 1,
            },
            blog_id         => {
                auto            => 1,
                col             => 'blog_id',
                display         => 'none',
                filter_editable => 0,
            },
            blog_name => {
                base      => '__common.blog_name',
                label     => sub {
                    MT->instance->blog
                        ? MT->translate('Blog Name')
                        : MT->translate('Website/Blog Name');
                },
                display   => 'default',
                site_name => sub { MT->instance->blog ? 0 : 1 },
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
                html    => \&AjaxRating::CMS::list_prop_object_content
            },
            created_by => {
                base    => '__virtual.author_name',
                label   => 'Created By',
                order   => 800,
                display => 'default',
                raw          => sub {
                    my ( $prop, $obj ) = @_;
                    my $col
                        = $prop->datasource->has_column('author_id')
                        ? 'author_id'
                        : 'created_by';

                    # If there's no value in the column then no voter ID was
                    # recorded.
                    return '' if !$obj->$col;

                    my $author = MT->model('author')->load( $obj->$col );
                    return $author
                        ? ( $author->nickname || $author->name )
                        : MT->translate('*User deleted*');
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

    sub summary_list_properties {
        return +{
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
        }
    }

    sub author {
        my $self  = shift;
        return $self->voter(@_) if $self->has_column('voter_id');
        state $User = MT->model('user');

        if ( my $user = shift ) {
            if ( looks_like_number($user) ) {
                $user = $self->{__author} = $User->load( $user );
            }
            elsif ( blessed($user) && $user->isa( $User ) ) {
                $self->{__author} = $user;
            }
            else { croak "Unknown author argument: ".$user }

            $self->author_id( $user ? $user->id : undef );
        }

        $self->{__author} ||= $User->load( $self->author_id )
            if $self->author_id;
    }

    sub blog {
        my $self     = shift;
        state $Blog = MT->model('blog');

        if ( my $blog = shift ) {
            if ( looks_like_number($blog) ) {
                $blog = $self->{__blog} = $Blog->load( $blog );
            }
            elsif ( blessed($blog) && $blog->isa( $Blog ) ) {
                $self->{__blog} = $blog;
            }
            else { croak "Unknown blog argument: ".$blog }

            $self->blog_id( $blog ? $blog->id : undef );
        }

        $self->{__blog} ||= $Blog->load( $self->blog_id ) if $self->blog_id;
    }

    sub object {
        my $self  = shift;
        my $class = $self->object_class or return;
        $self->{__object} ||= $class->load( $self->obj_id ) if $self->obj_id;
    }

    sub object_class {
        my $self  = shift;
        return if $self->{__no_object_class};

        unless ( $self->{__object_class} ) {
            my $class = $self->{__object_class} = MT->model( $self->obj_type )
                or $self->{__no_object_class} = 1;
        }
        $self->{__object_class};
    }

    sub object_terms {
        my $self = shift;
        return +{
            obj_id   => $self->obj_id,
            obj_type => $self->obj_type,
            $self->blog_id ? ( blog_id => $self->blog_id ) : ()
        };
    }

    # This will completely rebuild an object's votesummary record, which
    # *could* be expensive if a lot of vote records exist for the object.
    sub rebuild_votesummary_record {
        my ( $obj ) = @_;
        my $blog_id     = $obj->blog_id;
        my $obj_type    = $obj->obj_type;
        my $obj_id      = $obj->obj_id;
        my $app         = MT->instance;

        # Try to load an existing VoteSummary record so that it can be updated.
        my $VoteSummary = $app->model('ajaxrating_votesummary');
        my $vsumm       = $obj if $obj->isa($VoteSummary);
        $vsumm        ||= $VoteSummary->get_by_key( $obj->object_terms );

        # If no VoteSummary was found for this object, create one and populate
        # it with "getting started" values.
        unless ( $vsumm->author_id ) {
            my $author = $vsumm->author();
            $vsumm->author_id( $author->id ) if $author;
        }

        my $vote_count  = 0;
        my $total_score = 0;
        my $yaml        = YAML::Tiny->new; # For vote distribution data
        my $iter        = $vsumm->votes_iter();
        while ( my $vote = $iter->() ) {
            # Update the VoteSummary with details of this vote change.
            $vote_count++;
            $total_score               += $vote->score;
            $yaml->[0]->{$vote->score} += 1;
        }
        my $average
            = try { sprintf("%.1f", $total_score / $vote_count) } catch { 0 };

        $vsumm->set_values({
            vote_count  => $vote_count,
            total_score => $total_score,
            avg_score   => $average,
            vote_dist   => $yaml->write_string(),
        });

        $vsumm->save or die $vsumm->errstr;

        return $vsumm;
    }

    sub pre_save {
        shift @_; # $obj repeated from
        my ( $cb, $obj, $obj_orig ) = @_;
        require MT::Util;
        my $ts      = MT::Util::epoch2ts( undef, time );
        my $app     = MT->instance;
        my $user_id = $app->can('user') ? $app->user->id : undef;
        for ( $obj, $obj_orig ) {
            $_->modified_on($ts);
            $_->modified_by( $user_id );
        }

        # Sync author_id/voter_id and created_by, preferring the former
        sync_author_fields( $obj, $obj_orig,
            ( first_value { $obj->has_column($_) } qw( author_id voter_id ) ),
            'created_by'
        );
    }
}

1;

__END__
