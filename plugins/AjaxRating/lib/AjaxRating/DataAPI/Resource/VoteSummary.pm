package AjaxRating::DataAPI::Resource::VoteSummary;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use AjaxRating::DataAPI::Resource::HotObject;

sub fields {
    [
        @{ AjaxRating::DataAPI::Resource::HotObject::fields() },
        {
            name  => 'voteDist',
            alias => 'vote_dist',
        }
    ]
}

1;

__END__
