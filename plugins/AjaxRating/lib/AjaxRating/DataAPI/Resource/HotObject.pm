package AjaxRating::DataAPI::Resource::HotObject;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use MT::DataAPI::Resource;
use MT::DataAPI::Resource::Common;

sub fields {
    [
        {   name   => 'author',
            fields => [qw(id displayName userpicUrl)],
            from_object => sub {
                my $author = shift()->author or return;
                MT::DataAPI::Resource->from_object( $author );
            },
        },
        {   name   => 'avgScore',
            alias  => 'avg_score',
            from_object => sub {
                my $obj = shift or return;
                $obj->avg_score + 0
            },
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

1;

__END__
