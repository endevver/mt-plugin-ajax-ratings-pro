package AjaxRating::DataAPI::Endpoint::VoteSummary {

    use strict;
    use warnings;
    use 5.0101;  # Perl v5.10.1 minimum
    use MT::DataAPI::Endpoint::Common;
    use MT::DataAPI::Resource;
    use AjaxRating::DataAPI::Endpoint::Common;

    ### FIXME Break this into two methods:
    ###     1. Handling single object fetch
    ###     2. Handling list fetch
    sub fetch {
        my ( $app, $endpoint )         = @_;
        my ( $terms, $args, $options ) = setup_request( $app, $endpoint );
        return unless $terms;

        my $res = filtered_list( $app, $endpoint, 'ajaxrating_votesummary' )
            or return;

        unless ( ref($terms->{obj_id}) or $res->{count} > 1 ) {
            return shift @{ $res->{objects} || [] } || {};
        }

        my $items
            = MT::DataAPI::Resource::Type::ObjectList->new($res->{objects});

        return +{
            totalResults => $res->{count} + 0,
            itemCount    => scalar @{ $res->{objects} || [] },
            items        => $items,
        };
    }
}

1;

__END__

