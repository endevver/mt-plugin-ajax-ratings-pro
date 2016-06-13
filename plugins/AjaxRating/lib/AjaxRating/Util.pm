package AjaxRating::Util {

    use strict;
    use warnings;
    use 5.0101;  # Perl v5.10.1 minimum
    use Try::Tiny;
    use Carp            qw( croak );
    use Scalar::Util    qw( blessed looks_like_number );
    use List::MoreUtils qw( first_value first_result );

    use base qw( Exporter );
    our @EXPORT_OK = qw( get_config obj_to_type
                         pluralize_type pluralize reporter );

    sub get_config {
        my ( $scope, @keys ) = @_;
        $scope ||= 'system';

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

    sub obj_to_type {
        my ( $obj, $types ) = @_;
        $types ||= do { require MT; MT->registry('object_types') };

        croak("Not an MT object subclass instance")
            unless blessed($obj) && $obj->isa('MT::Object');

        my $class = ref($obj);
        my $type  = first_value { $types->{$_} eq $class } keys %$types;
        return ( $type, 'object_types grep' ) if $type;

        my $is_model = sub {
            my $t = shift           or return;
            my $m = MT->model($t)   or return;
            return 1 if $m eq $class;
        };

        if ( $type = $obj->class_type ) {

            $is_model->($type) && return ( $type, 'class_type' );

            $type = try { $obj->properties->{__class_to_type}{$class} }
                or croak(
                    "No __class_to_type found in $class object properties");
            $is_model->($type)
                && return ( $type, 'properties->{__class_to_type}{$class}');

            $type = $obj->datasource.'.'.$type;
            $is_model->($type) &&
                return ( $type, 'datasource.props->{__class_to_type}{$class}' );

            croak( 'Could not derive type from object of class '.$class
                 . ' with class_type '.$obj->class_type );
        }

        $is_model->($obj->datasource)
            && return ( $obj->datasource, 'datasource' );

        croak( 'Could not derive type from object of class '.$class );
    }

    sub pluralize_type {
        my $type = shift;
        return try {
            my $p = MT->model($type)->class_label_plural() || ' ';
            $p !~ /\s/ ? lc( $p ) : die;
        }
        catch {
            pluralize( $type )
        };
    }

    sub pluralize {
        my $str = shift;
        given ( $str ) {
            when ( /es$/ ) { $str =~ s/es$/esses/ }
            when ( /s$/ )  { $str =~ s/s$/ses/    }
            when ( /y$/ )  { $str =~ s/y$/ies/    }
            default        { $str = "${str}s"     }
        }
        $str;
    }

    sub reporter {
        require DDP if @_;
        my @caller = caller(1);
        say STDERR sprintf 'Reporting from %s (line %d) %s',
            @caller[3,2], (scalar @_ ? ' with: '.np(@_) : '');
    }

    sub np {
        require Data::Dumper;
        return Data::Dumper::Dumper([@_]);
    }
}

1;

__END__
