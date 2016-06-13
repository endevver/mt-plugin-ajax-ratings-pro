package AjaxRating::Types;

use 5.010;
use Moo;
use strictures 2;
with 'MooX::Singleton';
use Carp qw( croak );
use Try::Tiny;
use List::MoreUtils qw( uniq );
use AjaxRating::Util qw( get_config pluralize_type );
use Scalar::Util qw( blessed );
use MT;

our @CARP_NOT;

use constant DEBUG => 1;

has 'initialized_types' => (
    is      => 'rw',
    default => sub { +{} },
    clearer => 1,
);

has 'registry_types' => (
    is      => 'rwp',
    builder => 1,
    clearer => 1,
);

has 'system_config' => (
    is      => 'rwp',
    builder => 1,
    clearer => 1,
);

sub _build_registry_types {
    my $self = shift;
    my $r = MT->instance->registry( 'rateable_object_types' )
         || MT->instance->registry( 'rateable_object_types', {} );
}

sub _build_system_config {
    my $self   = shift;
    my $syscfg = get_config( 'system', 'rateable_object_types' );
    return $syscfg if $syscfg;

    # ONE-TIME INITIALIZATION NEEDED
    # If we don't have a system plugin config, create it
    # based on any existing ajaxrating_vote records.
    $syscfg  = {};
    my $iter = MT->model('ajaxrating_vote')
                 ->count_group_by( undef, { group => ['obj_type'] });

    while ( my ( $count, $obj_type ) = $iter->() ) {
        $syscfg->{$obj_type} = { type => $obj_type, enabled => 1 };
    }
    return $syscfg;
}

sub init {
    my ( $pkg, $cb, $mt, $param ) = @_;
    my $self     = $pkg->instance;
    my $regtypes = $self->registry_types;
    my $syscfg   = $self->system_config;

    foreach my $obj_type ( uniq keys( %$syscfg ), keys( %$regtypes ) ) {
        my $typecfg
            = $syscfg->{$obj_type} ||= { type => $obj_type, enabled => 1 };

        if ( my $reg = $regtypes->{$obj_type} ) {
            if ( ! keys %$typecfg ) {
                %$typecfg = %$reg;
            }
            else {
                $typecfg->{$_} = $reg->{$_}
                    foreach grep { $_ ne 'enabled' } keys %$reg;
                        # Registry can't override enabled
            }
        }
        $self->add_type( $typecfg );
    }
    $self->save_system_config($syscfg);
}

sub add_type {
    my ( $self, $typecfg ) = @_;
    $self     = $self->instance unless blessed($self);
    my $types = $self->initialized_types;
    my $type  = $types->{ $typecfg->{type} }
            ||= do {
                    require AjaxRating::Types::Type;
                    $typecfg->{obj_type} = delete $typecfg->{type};
                    AjaxRating::Types::Type->new( %$typecfg );
                };

    # if ( $type->enabled and ! $type->cb_initialized ) {
    unless ( $type->cb_initialized ) {
        foreach my $cbname (qw( pre_remove post_save )) {
            my $cb = $type->$cbname() or next;
            $self->create_callback($cb)
        }
        $type->cb_initialized(1);
    }
    return $type;
}

sub get_type {
    my ( $self, $obj_type ) = @_;
    $self = $self->instance unless blessed($self);
    return $self->initialized_types->{$obj_type}
            ||= $self->add_type({ type => $obj_type, enabled => 0 });
}

sub enable_type {
    my ( $self, $obj_type, $scope ) = @_;
    $self     = $self->instance unless blessed($self);
    my $types = $self->initialized_types;
    my $type  = $types->{$obj_type} or croak "Unknown rateable type: $obj_type";

    ...
}

sub disable_type {
    my ( $self, $obj_type, $scope ) = @_;
    $self     = $self->instance unless blessed($self);
    my $types = $self->initialized_types;
    my $type  = $types->{$obj_type} or croak "Unknown rateable type: $obj_type";

    ...
}

sub create_callback {
    my ( $self, $cb ) = @_;
    $cb = { plugin => AjaxRating->plugin, priority => 5, %$cb }; # Defaults

    my @bad = grep { ! defined $cb->{$_} } qw( name meth handler code );
    if ( @bad ) {
        local @CARP_NOT = __PACKAGE__;
        croak("Missing callback parameter(s): ".join(', ', @bad ));
    }

    # Define the actual subs and use config handler syntax because
    # then they are easily discoverable and testable
    {
        no strict 'refs';
        *{ $cb->{meth} } = $cb->{code};
    }

    MT->add_callback( $cb->{name}, $cb->{priority}, $cb->{plugin},
                      MT->handler_to_coderef( $cb->{handler} ) );
    DEBUG and
        printf STDERR "Created %s callback to %s\n",
            $cb->{name}, $cb->{handler};
}

sub current_scope {
    my $app     = MT->instance;
    my $blog_id = try { $app->blog->id }
               || try { $app->param('blog_id') };
    return $blog_id ? 'blog:'.$blog_id : 'system';
}

sub request_types {
    my $self = shift;
    ( ref $_[0] eq 'HASH' ? my ( $args ) : (my %args) ) = @_;

    # Handle single hashref argument; sets and returns
    return MT->request( 'rateable_object_types', $args ) if $args;

    # Get request object
    my $r  = MT->request( 'rateable_object_types' )
         ||= MT->request( 'rateable_object_types', {} );

    # Handle key/value hash arguments; sets key to value if key is defined
    my ( $k, $v ) = each %args;
    $r->{$k}      = $v if $k;

    $r    # Return request data
}

sub blog_config {
    my ( $self, $scope ) = @_;
    return {} if $scope eq 'system';
    return get_config( $scope, 'rateable_object_types' ) || {};
}

sub rateable_object_types {
    my ( $self, $scope ) = @_;
    $self        = $self->instance unless blessed($self);
    $scope     ||= $self->current_scope();

    # Check the request object for this scope's rateable_object_types
    my $r = $self->request_types;
    return $r->{$scope}{config} || {} if keys %{$r->{$scope}};

    my ( $config, @enabled );
    my $types   = $self->initialized_types;
    my $syscfg  = $self->system_config;
    my $blogcfg = $self->blog_config( $scope );


    foreach my $obj_type ( sort keys %$types ) {
        my ( $b, $s ) = map { $_->{$obj_type} || {} } $blogcfg, $syscfg;
        next unless $b->{enabled}
                 || ( $s->{enabled} && ! defined($b->{enabled}) );
        push( @enabled, $obj_type );
        $config->{$obj_type} = $types->{$obj_type};
        # {
        #     resources   => $default_resource,
        #     type        => $type,
        #     type_proxy  => $type,
        #     ### TODO Document post_save and pre_remove callback configuration
        #     # pre_remove => "$YourPlugin::YourPackage::${type}_pre_remove",
        #     # post_save   => "$YourPlugin::YourPackage::${type}_post_save",
        #     %$s,
        #     %$b
        # };
        # $config->{$type}{type_plural} ||= pluralize_type( $type );
    }

    $r->{$scope}{enabled} = \@enabled;
    $r->{$scope}{config}  = $config;

    return $config;

    # TODO Filter non-rateable? Hmmmmm
    # accesstoken association banlist config failedlogin fileinfo filter log
    # notification objectasset objectscore objecttag permission placement
    # plugindata role session template templatemap touch ts_error ts_exitstatus
    # ts_funcmap ts_job
}


# The object_type proxy is used for rating MT objects using alternate obj_type
# values.  For example, if you wanted to rate an entry on multiple facets. The
# default rating with the obj_type value 'entry' might mean "Like" but you
# could also rate the it on clarity and usefulness.  In these cases, the
# obj_type values might be "clarity" and "useful" with the obj_id value of the
# entry ID.  But since you can't look the entry up using those obj_type values,
# you could set the type_proxy value to 'entry' so it can be retrieved.
sub object_type_proxy {
    my ( $class, $type ) = @_;
    return unless $type;

    my $mt = MT->instance;

    my ( $mt_type, $model );
    if ( $model = $mt->model( $type ) ) {
        $mt_type = $type;
    }
    else {
        my $type_cfg = $class->rateable_object_types;
        $type        = $type_cfg->{$type}{type_proxy} if $type_cfg->{$type};
        if ( $type ) {
            $model = $mt->model( $type );
            $mt_type = $type if $model;
        }
    }
    return wantarray ? ( $mt_type, $model ) : $mt_type;

}

sub save_system_config {
    my $self = shift;
    my $cfg  = shift || $self->system_config;
    AjaxRating->plugin->set_config_value(
        'rateable_object_types', $cfg, 'system' );
}


1;

__END__


CACHING:

* APP: In $app object
Session
Plugindata
Request
mt-config.cgi / mt_config
Memcached

# MT::Cache::Session uses the 'kind' parameter
   # which accepts namespace of the cache
   my $cache = MT::Cache::Negotiate->new( ttl => 10, kind => 'XX' );
   my $data = $cache->get($key);
   $cache->set($key => $value);
   my $hash = $cache->get_multi($key1, $key2);


   require MT::Cache::Negotiate;
   $cache_driver = MT::Cache::Negotiate->new(
       ttl       => $ttl_for_get,
       expirable => 1
   );
   my $cache_value = $cache_driver->get($cache_key);
   $cache_value = Encode::decode( $enc, $cache_value );
   if ($cache_value) {
       return $cache_value if !$use_ssi;

     # The template may still be cached from before we were using SSI
     # for this template, so check that it's also on disk.
       my $include_file = $blog->include_path( \%include_recipe );
       if ( $blog->file_mgr->exists($include_file) ) {
           return $blog->include_statement( \%include_recipe );
       }
   }


   sub _cache_key {
       my $obj = shift;
       my ($term) = @_;
       my $key;
       if ( $term->{blog_id} ) {
           $key = sprintf "%sscore%s-%d-%d", $term->{object_ds},
               $term->{namespace}, $term->{object_id}, $term->{author_id};
       }
       elsif ( $term->{object_id} ) {
           $key = sprintf "%sscore%s-%d", $term->{object_ds}, $term->{namespace},
               $term->{object_id};
       }
       else {
           $key = sprintf "%sscore%s", $term->{object_ds}, $term->{namespace};
       }
       return $key;
   }
