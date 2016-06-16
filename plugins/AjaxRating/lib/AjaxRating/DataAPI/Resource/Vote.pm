package AjaxRating::DataAPI::Resource::Vote;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use MT::DataAPI::Resource;
use MT::DataAPI::Resource::Common;
use Try::Tiny;

sub fields {
    [
        {
            name        => 'blog',
            from_object => sub {
                my ( $obj ) = @_;
                if ( my $blog = resolve_object_blog($obj) ) {
                    return +{
                        id   => $blog->id,
                        name => $blog->name,
                        url  => $blog->site_url,
                    };
                }
                else {
                    return undef;
                }
            },
            bulk_from_object => sub {
                my ( $objs, $hashes ) = @_;
                for my $i ( 0 .. ( scalar(@$objs) - 1 ) ) {
                    my $obj = $objs->[$i];
                    if ( my $blog = resolve_object_blog($obj) ) {
                        $hashes->[$i]->{'blog'} = {
                            id   => $blog->id,
                            name => $blog->name,
                            url  => $blog->site_url,
                        };
                    }
                }
            }
        },
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

sub resolve_object_blog {
    my $obj     = shift;
    my $blog_id = $obj->blog_id || try { $obj->object->blog_id }
        or return;
    scalar MT->model('blog')->load({ id => $blog_id });
}

1;

__END__
