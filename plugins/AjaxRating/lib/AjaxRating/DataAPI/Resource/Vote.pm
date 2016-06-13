package AjaxRating::DataAPI::Resource::Vote;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use MT::DataAPI::Resource;
use MT::DataAPI::Resource::Common;

sub fields {
    [
        $MT::DataAPI::Resource::Common::fields{blog},
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
            from_object => sub {
                my $author = shift()->voter or return;
                MT::DataAPI::Resource->from_object( $author );
            },
        },
    ];
}

1;

__END__
