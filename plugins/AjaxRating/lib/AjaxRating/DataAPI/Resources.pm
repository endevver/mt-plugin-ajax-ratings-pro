package AjaxRating::DataAPI::Resources {

    use strict;
    use warnings;
    use 5.0101;  # Perl v5.10.1 minimum
    use MT::DataAPI::Resource::Common;
    # use DDP;

    sub vote_fields {
        [
            $MT::DataAPI::Resource::Common::fields{blog},
            'blog_id',
            $MT::DataAPI::Resource::Common::fields{createdDate},
            {
                name  => 'id',
                type  => 'MT::DataAPI::Resource::DataType::Integer',
            },
            'ip',
            $MT::DataAPI::Resource::Common::fields{modifiedDate},
            {   name   => 'object',
                from_object => sub {
                    my $obj = shift()->object or return;
                    MT::DataAPI::Resource->from_object( $obj );
                },
            },
            {   name  => 'objId',
                alias => 'obj_id',
                type  => 'MT::DataAPI::Resource::DataType::Integer',
            },
            {   name  => 'objType',
                alias => 'obj_type',
            },
            {   name  => 'score',
                type  => 'MT::DataAPI::Resource::DataType::Integer',
            },
            {   name   => 'voter',
                fields => [qw(id displayName userpicUrl)],
                type   => 'MT::DataAPI::Resource::DataType::Object',
            },
        ];
    }


    sub votesummary_fields {
        [
            @{ hotobject_fields() },
            {
                name  => 'voteDist',
                alias => 'vote_dist',
            }
        ]
    }

    sub hotobject_fields {
        [
            {   name   => 'author',
                fields => [qw(id displayName userpicUrl)],
                type   => 'MT::DataAPI::Resource::DataType::Object',
            },
            {   name   => 'avgScore',
                alias  => 'avg_score',
            },
            $MT::DataAPI::Resource::Common::fields{blog},
            $MT::DataAPI::Resource::Common::fields{createdDate},
            {
                name   => 'id',
                type   => 'MT::DataAPI::Resource::DataType::Integer',
            },
            $MT::DataAPI::Resource::Common::fields{modifiedDate},
            {   name   => 'object',
                # fields => [qw(id)],
                from_object => sub {
                    my $obj = shift()->object or return;
                    MT::DataAPI::Resource->from_object( $obj );
                },
            },
            {   name   => 'objType',
                alias  => 'obj_type',
            },
            {   name   => 'objId',
                alias  => 'obj_id',
                type   => 'MT::DataAPI::Resource::DataType::Integer',
            },
            {   name   => 'voteCount',
                alias  => 'vote_count',
                type   => 'MT::DataAPI::Resource::DataType::Integer',
            },
            {   name   => 'totalScore',
                alias  => 'total_score',
                type   => 'MT::DataAPI::Resource::DataType::Integer',
            },
        ];
    }

    # Add a `ratings` hash to an entry object in the data API.
    sub object_summary {
        return [
            {   name             => 'ratings',
                from_object      => \&from_object,
                bulk_from_object => sub {
                    my ( $objs, $hashes ) = @_;
                    my $i = 0;
                    $hashes->[$i++]->{ratings} = from_object( $_ )
                        foreach @$objs;
                },
            }
        ];
    }

    sub from_object {
        my ( $obj ) = @_;
        my $app      = MT->instance;
        my $Summary  = $app->model('ajaxrating_votesummary');
        my $Vote     = $app->model('ajaxrating_vote');
        my $obj_type = $obj->isa($app->model('comment')) ? 'comment' : 'entry';
        my %terms    = ( obj_type => $obj_type, obj_id => $obj->id );

        my $data     = {};

        # Add current user's rating, if one exists
        my $user = $app->user;
        if ( $user && $user->id ) { # Saved and not anonymous
            if ( my $vote = $Vote->load({ voter_id => $user->id, %terms }) ) {
                $data->{userRating} = 0 + $vote->score;
            }
        }

        my %map = ( # MT uses camel-case for the Data API
            avg_score   => 'avgScore',
            total_score => 'totalScore',
            vote_count  => 'voteCount',
        );
        my $summary       = $Summary->get_by_key( \%terms );
        $data->{$map{$_}} = 0 + ($summary->$_||0) foreach keys %map;

        return $data;
    }
}

1;

__END__
