package AjaxRating::Object {

    use strict;
    use warnings;
    use 5.0101;  # Perl v5.10.1 minimum
    use Try::Tiny;
    use Carp            qw( croak );
    use List::MoreUtils qw( first_value );
    use AjaxRating::Util qw( reporter );

    use parent qw( MT::Object );

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

    sub obj_type_proxy {
        my $self = shift;
        require AjaxRating::Types;
        AjaxRating::Types->get_type( $self->obj_type )->datasource;
    }

    sub object_class {
        my $self  = shift;
        return '' if $self->{__no_object_class};

        unless ( $self->{__object_class} ) {
            if ( my $type = $self->obj_type_proxy ) {
                $self->{__object_class} = MT->model( $type );
            }
            $self->{__no_object_class} = 1 unless $self->{__object_class};
        }
        $self->{__object_class};
    }

    sub object_terms {
        my $self = shift;
        return +{
            obj_id   => $self->obj_id,
            obj_type => $self->obj_type,
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
        # reporter(@_);

        my $is_vote = $obj->has_column('voter_id') ? 1 : 0;
        my $is_new  = ! ( $obj->{__resave} = $obj->id ? 1 : 0 );

        my ( $modified_by, $created_by );
        if ( $is_vote ) {
            $modified_by = $obj->voter_id;
            $created_by  = $obj->voter_id if $is_new;
        }
        else {
            my $vote = $obj->{__vote} || $obj_orig->{__vote};
            $modified_by = $vote->voter_id;
            $created_by  = $obj->author_id if $is_new;
        }

        require MT::Util;
        my $ts       = MT::Util::epoch2ts( undef, time );
        my $blog_id  = $obj->blog_id || try { $obj->object->blog_id };

        for ( $obj, $obj_orig ) {
            $_->modified_on( $ts )          if $ts;
            $_->modified_by( $modified_by ) if $modified_by;
            $_->created_by( $created_by )   if $created_by;
            $_->blog_id( $blog_id )         if $blog_id;
        }
        return 1;
    }

    # Remove the all AjaxRating records related to an object, usually in
    # response to the object's deletion.  This can be called as either a class
    # or object method.
    #    my ( $Vote, $Summary, $Hot ) = map { MT->model($_) } qw(
    #       ajaxrating_vote  ajaxrating_votesummary ajaxrating_hotobject
    #    );
    #    $Vote->purge   ( { obj_type => ..., obj_id => ... } );
    #    $Summary->purge( { obj_type => ..., obj_id => ... } );
    #    $Hot->purge    ( { obj_type => ..., obj_id => ... } );
    #
    # The object method takes its arguments from object_terms():
    #
    #    $vote->purge();
    #    $summary->purge();
    #    $hot->purge();
    #
    # NOTE: AjaxRating::Object::Vote::post_remove callbacks ARE NOT INVOKED.
    #       Only $AjaxRating::Object::Vote::pre_remove_multi will be invoked.
    sub purge {
        my $self  = shift;
        my $terms = shift;

        if ( ref($terms) eq 'HASH' ) {
            # Restrict terms to obj_id and obj_type
            $terms = { map { $terms->{$_} || '' } qw( obj_id obj_type ) };
        }
        elsif ( blessed( $self ) ) {
            $terms = $self->object_terms;
        }
        else {
            return $self->error('Class method purge requires hashref argument');
        }

        foreach my $key (qw( obj_type obj_id )) {
            next if $terms->{$key};
            return $self->error(  "Invalid $key specified: "
                                . ($terms->{$key}//'UNDEFINED') );
        }

        my @types
            = qw( ajaxrating_vote ajaxrating_votesummary ajaxrating_hotobject );
        foreach my $type ( @types ) {
            MT->model($type)->remove( $terms, { nofetch => 1 } );
        }

        my $Log = MT->model('log');
        my $msg = sprintf( 'AjaxRatings removed for %s ID %s',
                            map { $terms->{$_} } qw( obj_type obj_id ) );
        MT->instance->log(
            level    => $Log->INFO(),
            message  => $msg,
        );
    }
}

1;

__END__

Class->remove({}) does:
    MT->run_callbacks( $obj . '::pre_remove_multi', @args );
    return $obj->driver->direct_remove( $obj, @args );

Class->remove({}, { nofetch => 1 })
    does $driver->direct_remove($orig_obj, @_)

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



package Data::ObjectDriver::Driver::DBI;


sub remove {
    my $driver = shift;
    my $orig_obj = shift;

    ## If remove() is called on class method and we have 'nofetch'
    ## option, we remove the record using $term and won't create
    ## $object. This is for efficiency and PK-less tables
    ## Note: In this case, triggers won't be fired
    ## Otherwise, Class->remove is a shortcut for search+remove
    unless (ref($orig_obj)) {
        if ($_[1] && $_[1]->{nofetch}) {
            return $driver->direct_remove($orig_obj, @_);
        } else {
            my $result = 0;
            my @obj = $driver->search($orig_obj, @_);
            for my $obj (@obj) {
                my $res = $obj->remove(@_) || 0;
                $result += $res;
            }
            return $result || 0E0;
        }
    }

    return unless $orig_obj->has_primary_key;

    if ($Data::ObjectDriver::RESTRICT_IO) {
        die "Attempted DBI I/O while in restricted mode: remove()";
    }

    ## Use a duplicate so the pre_save trigger can modify it.
    my $obj = $orig_obj->clone_all;
    $obj->call_trigger('pre_remove', $orig_obj);

    my $tbl = $driver->table_for($obj);
    my $sql = "DELETE FROM $tbl\n";
    my $stmt = $driver->prepare_statement(ref($obj), $obj->primary_key_to_terms);
    $sql .= $stmt->as_sql_where;
    my $dbh = $driver->rw_handle($obj->properties->{db});
    $driver->start_query($sql, $stmt->{bind});
    my $sth = $driver->_prepare_cached($dbh, $sql);
    my $result = $sth->execute(@{ $stmt->{bind} });
    _close_sth($sth);
    $driver->end_query($sth);

    $obj->call_trigger('post_remove', $orig_obj);

    $orig_obj->{__is_stored} = 1;
    return $result;
}

sub direct_remove {
    my $driver = shift;
    my($class, $orig_terms, $orig_args) = @_;

    if ($Data::ObjectDriver::RESTRICT_IO) {
        die "Attempted DBI I/O while in restricted mode: direct_remove() " . Dumper($orig_terms, $orig_args);
    }

    ## Use (shallow) duplicates so the pre_search trigger can modify them.
    my $terms = defined $orig_terms ? { %$orig_terms } : {};
    my $args  = defined $orig_args  ? { %$orig_args  } : {};
    $class->call_trigger('pre_search', $terms, $args);

    my $stmt = $driver->prepare_statement($class, $terms, $args);
    my $tbl  = $driver->table_for($class);
    my $sql  = "DELETE from $tbl\n";
       $sql .= $stmt->as_sql_where;

    # not all DBD drivers can do this.  check.  better to die than do
    # unbounded DELETE when they requested a limit.
    if ($stmt->limit) {
        Carp::croak("Driver doesn't support DELETE with LIMIT")
            unless $driver->dbd->can_delete_with_limit;
        $sql .= $stmt->as_limit;
    }

    my $dbh = $driver->rw_handle($class->properties->{db});
    $driver->start_query($sql, $stmt->{bind});
    my $sth = $driver->_prepare_cached($dbh, $sql);
    my $result = $sth->execute(@{ $stmt->{bind} });
    _close_sth($sth);
    $driver->end_query($sth);
    return $result;
}


package MT::Object::BaseObject;

sub direct_remove {
    my $driver = shift;
    my ( $class, $orig_terms, $orig_args ) = @_;
    $class->call_trigger( 'pre_direct_remove', $orig_terms, $orig_args );
    $driver->SUPER::direct_remove(@_);
}


package MT::Object;

sub remove {
    my $obj = shift;
    my (@args) = @_;
    if ( !ref $obj ) {
        for my $which (qw( meta summary )) {
            my $meth = "remove_$which";
            my $has  = "has_$which";
            $obj->$meth(@args) if $obj->$has;
        }
        $obj->remove_scores(@args) if $obj->isa('MT::Scorable');
        MT->run_callbacks( $obj . '::pre_remove_multi', @args );
        return $obj->driver->direct_remove( $obj, @args );
    }
    else {
        return $obj->driver->remove( $obj, @args );
    }
}

sub remove_ratings {
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


1;

__END__
