package AjaxRating::Util {

    use strict;
    use warnings;
    use 5.0101;  # Perl v5.10.1 minimum
    use Scalar::Util qw( blessed looks_like_number );
    use List::MoreUtils qw( first_value first_result );

    use base qw( Exporter );
    our @EXPORT_OK = qw( get_config sync_author_fields );

    sub get_config {
        my ( $scope, @keys ) = @_;

        # Scope can be a blog_id, a blog object or any normally supported
        # scope e.g. system or blog:NNN (where NNN is the blog_id)
        if ( blessed($scope) && $scope->isa( MT->instance->model('blog') ) ) {
            $scope = 'blog:'.$scope->id;
        }
        elsif ( looks_like_number($scope) ) {
            $scope = 'blog:'.$scope;
        }

        # Get config from request cache or create it if necessary
        my $r     = MT->request;
        my $cache = $r->cache( 'ajaxrating_configs',
                               $r->cache('ajaxrating_configs') || {} );
        my $c = $cache->{$scope}
            ||= MT->component('ajaxrating')->get_config_hash($scope);
        if ( $c ) {
            return scalar @keys == 1 ? $c->{shift(@keys)}
                 : scalar @keys      ? ( map { $c->{$_} } @keys )
                                     : $c;
        }
    }

    sub sync_author_fields {
        my ( $obj, $orig_obj, @fields ) = @_;
        my $author_id;
        unless ( $author_id = first_value { $_ } map { $obj->$_ } @fields ) {
            my $app = MT->instance;
            my $meth   = $app->can('user') or return;
            my $user   = $meth->($app)  or return;
            $author_id = $user->id      or return;
        }
        foreach my $f ( @fields ) {
            $obj->$f( $author_id );
            $orig_obj->$f( $author_id );
        }
    }
}

1;

__END__
