package AjaxRating::Object::HotObject;

use strict;
use warnings;
use Scalar::Util qw( blessed );

use AjaxRating::Object;
@AjaxRating::Object::HotObject::ISA = qw( AjaxRating::Object );

__PACKAGE__->install_properties({
    column_defs => {
        'id'          => 'integer not null auto_increment',
        'blog_id'     => 'integer default 0',
        'obj_type'    => 'string(50) not null',
        'obj_id'      => 'string(255) default 0',
        'author_id'   => 'integer default 0',
        'vote_count'  => 'integer default 0',
        'total_score' => 'integer default 0',
        'avg_score'   => 'float default 0'
    },
    defaults    => {
        obj_type => 'entry',
        map { $_ => 0 } qw( blog_id  vote_count   author_id
                            obj_id   total_score  avg_score ),
    },
    indexes     => {
        map { $_ => 1 } qw(
            blog_id  obj_type  obj_id  author_id
            vote_count  total_score  avg_score
        )
    },
    audit       => 1,
    datasource  => 'ar_hotobj',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Hot Object");
}

sub class_label_plural {
    MT->translate("Hot Objects");
}

sub list_properties {
    my $self  = shift || __PACKAGE__;
    my $class = blessed($self);
    $class    = __PACKAGE__ if ! $class or $class eq 'MT::Plugin';
    $self     = $self->new() unless blessed($self);
    return +{
        %{ $self->SUPER::list_properties()         },
        %{ $self->SUPER::summary_list_properties() },
    };
}

sub pre_save {
    my ( $cb, $obj, $obj_orig ) = @_;
    $obj->SUPER::pre_save(@_);
}

1;

__END__
