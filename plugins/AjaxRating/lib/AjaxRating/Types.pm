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
# use DDP {
#     caller_info => 1,
#     filters     => {
#         'MT::App::CMS' => sub { say '[DDP] App: ', $_[0] },
#         'MT::Plugin'   => sub { say '[DDP] Plugin '.$_[0]->id, ': ', $_[0] }
#     }
# };

our @CARP_NOT;

use constant DEBUG => 0;

has 'initialized_types' => (
    is      => 'rw',
    default => sub { +{} },
    clearer => 1,
);

has 'registry_types' => (
    is      => 'rwp',
    lazy    => 1,
    clearer => 1,
    builder => 1,
);

has 'system_config' => (
    is      => 'rwp',
    builder => 1,
    clearer => 1,
);

sub _build_registry_types {
    my $types = {};
    my $rs    = MT::Plugin->registry( 'rateable_object_types' ) || [];
    foreach my $r ( @$rs ) {
        foreach my $obj_type ( keys %$r ) {
            if ( $types->{$obj_type} ) {
                die sprintf
                      'rateable_object_types conflict: Two plugins attempted '
                    . 'to register the same object type "%s": %s', $obj_type,
                    join(' and ',
                        map { $_->{$obj_type}{plugin}->name } $types, $r );
            }
            $r->{$obj_type}{obj_type} ||= $obj_type;
            $types->{$obj_type}         = $r->{$obj_type};
        }
    }
    delete $types->{$_}{plugin} foreach keys %$types;
    return $types;
}

sub _build_system_config {
    my $self   = shift;
    my $syscfg = get_config( 'system', 'rateable_object_types' ) || {};
    return $syscfg if keys %$syscfg;

    # ONE-TIME INITIALIZATION NEEDED
    # If we don't have a system plugin config, create it
    # based on any existing ajaxrating_vote records.
    $syscfg  = {};
    my $iter = MT->model('ajaxrating_vote')
                 ->count_group_by( undef, { group => ['obj_type'] });

    while ( my ( $count, $obj_type ) = $iter->() ) {
        $syscfg->{$obj_type} = { obj_type => $obj_type, enabled => 1 };
    }

    if ( keys %$syscfg ) {
        say STDERR '_build_system_config: Found the following obj_types in the '
                 . 'ar_vote table: '.join(', ', keys %$syscfg );
    }
    else {
        $syscfg->{$_} = { obj_type => $_, enabled => 1 }
            foreach qw( entry page comment );
        say STDERR '_build_system_config: No obj_types found in ar_vote table. '
             .'Using default setup '.join(', ', keys %$syscfg );
    }
    return $syscfg
}

sub init {
    my ( $pkg, $cb, $mt, $param ) = @_;
    my $self     = $pkg->instance;
    my $regtypes = $self->registry_types;
    my $syscfg   = $self->system_config;

    foreach my $obj_type ( uniq keys( %$syscfg ), keys( %$regtypes ) ) {
        my $typecfg = $syscfg->{$obj_type}
                        ||= { obj_type => $obj_type, enabled => 1 };

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
    my $type  = $types->{ $typecfg->{obj_type} }
                    ||= do {
                            require AjaxRating::Types::Type;
                            AjaxRating::Types::Type->new( %$typecfg );
                        };

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
            ||= $self->add_type({ obj_type => $obj_type, enabled => 0 });
}

sub request_types {
    my $self = shift;
    ( ref $_[0] eq 'HASH' ? my ( $args ) : (my %args) ) = @_;

    # Handle single hashref argument; sets and returns
    return MT->request( 'rateable_object_types', $args ) if $args;

    # Get request object
    my $r  = MT->request( 'rateable_object_types' )
          || MT->request( 'rateable_object_types', {} );

    # Handle key/value hash arguments; sets key to value if key is defined
    my ( $k, $v ) = each %args;
    $r->{$k}      = $v if $k;

    $r    # Return request data
}

sub enabled_types {
    my ( $self, $scope ) = @_;
    $self    = $self->instance unless blessed($self);
    $scope ||= $self->current_scope();

    # Check the request object for this scope's rateable_object_types
    my $r = $self->request_types;
    return $r->{$scope} if keys %{$r->{$scope}};

    my ( $config, @enabled ) = ( {} );
    my $types   = $self->initialized_types;
    my $syscfg  = $self->system_config;
    my $blogcfg = $scope eq 'system' ? {} : $self->blog_config( $scope );

    foreach my $obj_type ( sort keys %$types ) {
        my ( $b, $s ) = map { $_->{$obj_type} || {} } $blogcfg, $syscfg;
        if ( $b->{enabled} || ( $s->{enabled} && ! defined($b->{enabled}) )) {
            $config->{$obj_type} = $types->{$obj_type};
        }
    }

    $r->{$scope} = $config;
    return $config;
}

sub enable_type {
    my ( $self, $obj_type, $scope ) = @_;
    croak "Scope argument required. Use system, blog:N or all" unless $scope;
    $self     = $self->instance unless blessed($self);
    my $types = $self->initialized_types;
    my $type  = $types->{$obj_type}
        or croak "Unknown rateable type: $obj_type. Use add_type first";
    ...
}

sub disable_type {
    my ( $self, $obj_type, $scope ) = @_;
    croak "Scope argument required. Use system, blog:N or all" unless $scope;
    $self     = $self->instance unless blessed($self);
    my $types = $self->initialized_types;
    my $type  = $types->{$obj_type}
        or croak "Unknown rateable type: $obj_type. Use add_type first";
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
    $cb->{meth} =~ m{(.+)::(.+)}
        or die "Bad callback method name: ".$cb->{meth};
    my ($pkg, $sub) = ( $1, $2 );

    unless ( $pkg->can( $sub ) ) {
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
               || try { $app->param('blog_id') || $app->param('site_id') };
    return $blog_id ? 'blog:'.$blog_id : 'system';
}

sub blog_config {
    my ( $self, $scope ) = @_;
    croak "Invalid scope 'system'. Use system_config method instead"
        if $scope eq 'system';

    $scope ||= $self->current_scope();
    croak "No blog scope specified" unless $scope and $scope ne 'system';

    return get_config( $scope, 'rateable_object_types' ) || {};
}

sub save_system_config {
    my $self = shift;
    my $cfg  = shift || $self->system_config;
    $self->save_config( $cfg, 'system' );
}

sub save_config {
    my $self = shift;
    my ( $cfg, $scope ) = @_;
    die "No config specified" unless $cfg;
    die "No scope specified"  unless $scope;
    AjaxRating->plugin->set_config_value('rateable_object_types', $cfg, $scope);
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
