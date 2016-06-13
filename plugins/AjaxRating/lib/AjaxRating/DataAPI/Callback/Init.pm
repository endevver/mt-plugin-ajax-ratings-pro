package AjaxRating::DataAPI::Callback::Init;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use Clone qw( clone );
# use DDP { filters => {
#     'MT::App::CMS' => sub { say 'App: ', $_[0] },
#     'MT::Plugin'   => sub { say $_[0]->id, ': ', $_[0] }
# }};

sub init_app {
    my ( $plugin, $app ) = @_;

    my $data_api = AjaxRating->plugin->registry(qw( applications data_api ));

    # TODO I just could not make the following work so I duplicated the resources in config.yaml
    # my $resources = $data_api->{resources};
    # backport_ar_resources( $app, $resources );

    my $endpoints = $data_api->{endpoints};
    my $object_endpoints
        = [ grep { $_->{id} =~ m/^ar_object/ } @$endpoints ];

    ### Now insert resources for all rateable objects. By default,
    ### this will add a 'ratings' hash into entry, page and comment
    ### resources
    my $types  = AjaxRating->rateable_object_types;
    foreach my $type ( keys %$types ) {
        foreach my $ep ( @$object_endpoints ) {
            my $new_ep = objectify_endpoint( clone($ep), $types->{$type} );
            push( @$endpoints, $new_ep );
        }
    }
}

sub objectify_endpoint {
    my ( $ep, $type_cfg ) = @_;

    my $type = $type_cfg->{type};

    # ar_object_fetch_summary -> ar_entry_fetch_summary
    $ep->{id} =~ s{^ar_object}{ar_$type};

    # :obj_type -> :entries
    $ep->{route} =~ s{obj_type}{$type_cfg->{type_plural}};

    # :obj_id(s) -> :entry_id(s)
    $_ =~ s{obj_id}{${type}_id}
        foreach $ep->{route},
                $ep->{default_params}{id_param};
    $ep;
}

# TODO I just could not make the following work so I duplicated the resources in config.yaml
# MT doesn't like the object type and datasource being different but
# long ago we had to shorten the long datasources for Oracle's sake.
# So now we have short datasources (ar_vote) and longer object types
# (ajaxrating_vote).  The Data API uses the datasource in making the
# resources and hence this...
sub backport_ar_resources {
    my ( $app, $resources ) = @_;
    #
    # require AjaxRating;
    # my @obj_types = keys %{ AjaxRating->plugin->registry('object_types') }
    #     or die "No object types found";
    #
    # # Make mapping from object_type to datasource
    # #   (e.g. ajaxrating_vote => ar_vote)
    # my %ds = map { $_ => $app->model($_)->datasource } @obj_types;
    #
    # p $resources;
    # foreach my $res ( @$resources ) {
    #     p $res;
    #     next unless $res->{plugin}->id eq 'ajaxrating';
    # }
    # ### Copy resources from ajaxrating_* to ar_*
    # foreach my $type ( @obj_types ) {
    #     say STDERR "Duplicating $type resources to $ds{$type}";
    #     next if $resources->{$ds{$type}} = $resources->{$type};
    #     die 'No resource found for $type';
    # }
}

1;

__END__
