package SocialStats::Entry::AjaxRating;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use MT;

sub social_count {
    my $pkg     = shift;
    my ( $entry ) = @_;
    my $vs      = MT->model('ajaxrating_votesummary')->load({
        obj_type => 'entry',
        obj_id   => $entry->id
    });
    my $count = $vs->total_score if $vs;
    return $count || 0;
}

1;
