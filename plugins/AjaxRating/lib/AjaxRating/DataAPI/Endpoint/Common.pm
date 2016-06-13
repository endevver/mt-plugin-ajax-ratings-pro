package AjaxRating::DataAPI::Endpoint::Common;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use Try::Tiny;
use MT::DataAPI::Endpoint::Common;
use MT::DataAPI::Resource;

use base 'Exporter';
our @EXPORT = qw( setup_request );

### TODO Try to eliminate all of this
sub setup_request {
    my ( $app, $endpoint, @required ) = @_;
    my $id = $app->param('id_param');

    push( @required, 'obj_type', $id )
        unless $endpoint->{id} eq 'fetch_vote_by_id';

    my ( $terms, $args, $options );

    $app->param( 'format',    $app->param('format')    || 'json'    );
    $app->param( 'sortOrder', $app->param('direction') || 'descend' );

    my %param = $app->param_hash;

    my $blog_id   = $app->param('site_id') || $app->param('blog_id');
    my $blog = MT->model('blog')->load( $blog_id ) if $blog_id;
    if ( $blog ) {
        $app->blog( $blog );
        $terms->{blog_id} = $blog_id;
    }

    $param{obj_type} =~ s{ies$}{y};
    $param{obj_type} =~ s{s$}{};

    unless ( $param{$id} ) {
        my $id_field   = ($param{obj_type} || '').'_id';
        my $obj_id     = delete $param{$id_field};
        $param{$id}    = $obj_id if $obj_id;
    }

    my @missing
        = grep { #say "Setting terms for $_";
                 ! defined( $terms->{$_} = $param{$_} ) } @required;

    if ( @missing ) {
        my $missing = join(', ', @missing );
        # p %{{ $app->param_hash }};
        return $app->error("Required parameters not found: $missing");
    }

    $terms->{obj_id} ||= delete $terms->{obj_ids};
    if ( $terms->{obj_id} =~ m{,} ) {
        if ( $app->request_method eq 'POST' ) {
            return $app->error(
                'You cannot make a POST request against multiple objects' );
        }
        $terms->{obj_id} = [ split( /\s*,\s*/, $terms->{obj_id} ) ];
        $args->{limit}   = scalar @{ $terms->{obj_id} };
    }

    $args->{limit} ||= $param{limit} || 10;

    return ( $terms, $args, $options ) unless @missing;
}

1;

__END__

