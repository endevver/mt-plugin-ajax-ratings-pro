package AjaxRating::Types::Type;

use 5.010;
use Moo;
use strictures 2;
use Carp qw( croak );
use AjaxRating::Util qw( get_config pluralize_type );
use MT;

use constant DEBUG => 1;

has 'obj_type' => (
    is       => 'ro',
    required => 1,
);

has 'obj_type_plural' => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
);

has 'datasource' => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
);
*ds = \&datasource;

has 'resources' => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
);

has 'disabled_scope' => (
    is      => 'ro',
    lazy    => 1,
    builder => sub { +{' system' => 0 } },
);

has 'pre_remove' => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
);

has 'post_save' => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
);

has 'cb_initialized' => (
    is      => 'rw',
    lazy    => 1,
    default => sub { 0 }
);

has 'blog_id_required' => (
    is      => 'ro',
    lazy    => 1,
    default => sub { 0 },
);

sub _build_obj_type_plural {
    pluralize_type( shift()->obj_type )
}

sub _build_datasource {
    my $self = shift;
    MT->model( $self->obj_type ) ? $self->obj_type : '';
}

sub _build_resources {
    MT->registry( qw( applications data_api resources DEFAULT ) );
}

### TODO Document post_save and pre_remove callback configuration
# pre_remove => "$YourPlugin::YourPackage::${type}_pre_remove",
# post_save   => "$YourPlugin::YourPackage::${type}_post_save",

sub _build_pre_remove {
    my $self  = shift;
    my $ds    = $self->datasource or return; # Skip fake obj_type w/ no ds
    my $model = MT->model( $ds )  or return; # Skip if type isn't a model
    my $type  = $self->obj_type;
    my $meth  = "${type}_delete_handler";
    return if $self->can( $meth );          # Skip already-defined handlers

    my $handler = join( '::', '$AjaxRating', ref($self), $meth );
    return +{
        name     => "$model\::pre_remove",
        meth     => ref($self)."::$meth",
        handler  => $handler,
        code     => sub { delete_handler( @_, $ds ) },
    }
}

sub _build_post_save {
    my $self    = shift;
    my $ds      = $self->datasource;
    return unless $ds =~ m/^(entry|comment|ping|trackback)$/;

    my $model   = MT->model($ds);
    my $meth    = "${ds}_post_save";
    my $handler = join( '::', '$AjaxRating', ref($self), $meth );
    my $code    = sub {
        my $hidden = $ds eq 'entry' ? ( $_[1]->status != 2 )
                                    : ( ! $_[1]->visible   );
        $self->touch_summary( @_, $hidden ? "${ds}0" : $ds );
    }; ### TODO TEST! I reversed the visible conditional above; it looked wrong

    return +{
        name     => "$model\::post_save",
        meth     => ref($self)."::$meth",
        handler  => $handler,
        code     => $code,
    }
}

sub delete_handler {
    my ( $cb, $obj, $type ) = @_;

    ### FIXME Need to overload this class to produce the type in string context
    my @types   = grep { $_->ds eq $type } AjaxRating->rateable_object_types
        or return;

    my $types   = @types > 1 ? \@types : $types[0];
    my @classes = qw(
        ajaxrating_vote
        ajaxrating_votesummary
        ajaxrating_hotobjects
    );

    foreach my $class ( @classes ) {
        MT->model($class)->remove(
            { 'obj_type' => $types, 'obj_id' => $obj->id, },
            { nofetch => 1 }
            # nofetch is faster because it skips search/load before removing.
        );
    }
}

sub touch_summary {
    my ( $self, $cb, $obj, $obj_type ) = @_;

    # If $obj_type is foo0, $alt_type is foo and vice versa
    my $alt_type    = $obj_type =~ m{^(.*)0$} ? $1 : "${obj_type}0";

    # Load using both obj_type variants in case there was a visibility change
    my $vsumm = MT->model('ajaxrating_votesummary')->load({
        obj_id => $obj->id, obj_type => [ $obj_type, $alt_type ]
    }) or return;

    # Set the obj_type based on the current visbility of the object
    $vsumm->obj_type( $obj_type );

    unless ( $vsumm->save ) {
        return $cb->error(sprintf(
            "Could not update AjaxRating votesummary timestamp for %s ID %d",
            $obj_type, $obj->id, $vsumm->errstr || 'Unknown error'
        ));
    }
}

sub enable {
    my ( $self, $scope ) = @_;
    ...
 }

sub disable {
    my ( $self, $scope ) = @_;
    ...
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

    require MT;
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
