package AjaxRating::DataAPI::Resource::Blog;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use MT;
use AjaxRating::Types;
use AjaxRating::DataAPI::Resource::Foreign;
use AjaxRating::Util qw( obj_to_type );

sub fields {
    [
        {
            name        => 'rateable_types',
            from_object => \&rateable_types,
            bulk_from_object => sub {
                my ( $objs, $hashes ) = @_;
                my $i = 0;
                $hashes->[$i++]->{rateable_types} = rateable_types( $_ )
                    foreach @$objs;
            }
        },
        @{ AjaxRating::DataAPI::Resource::Foreign::fields() }
    ]
}

sub rateable_types {
    my ( $obj )    = @_;
    my $Types      = AjaxRating::Types->instance;
    my $enabled    = $Types->enabled_types('blog:'.$obj->id);
    my $types      = { map { $_ => { enabled => \1 } } keys %$enabled };
    $types->{$_}{enabled}
                 ||= \0 foreach keys %{ $Types->initialized_types };
    return $types;
}

1;

__END__
