package AjaxRating::Vote;
use strict;
use warnings;
use YAML::Tiny;

use MT::Object;
@AjaxRating::Vote::ISA = qw(MT::Object);
__PACKAGE__->install_properties({
    column_defs => {
        'id'       => 'integer not null auto_increment',
        'blog_id'  => 'integer default 0',
        'voter_id' => 'integer default 0',
        'obj_type' => 'string(50) not null',
        'obj_id'   => 'string(255) default 0',
        'score'    => 'integer default 0',
        'ip'       => 'string(15)'
    },
    indexes => {
        voter_id => 1,
        blog_id => 1,
        obj_type => 1,
        obj_id => 1,
        ip => 1
    },
    audit => 1,
    datasource => 'ar_vote',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Vote");
}

sub class_label_plural {
    MT->translate("Votes");
}

## subnet will return the first 3 sections of an IP address.  
## If passed 24.123.2.45, it will return 24.123.2

sub subnet {
    my $vote = shift;
    my $ip = $vote->ip;
    my @parts = split(/\./,$ip);
    my $subnet = $parts[0] . "." . $parts[1] . "." . $parts[2];
    return $subnet;
}

# Properties for the listing framework, to show the vote activity log.
sub list_properties {
    require AjaxRating::CMS;
    return {
        id => {
            label   => 'ID',
            display => 'optional',
            order   => 1,
            auto    => 1,
        },
        blog_name => {
            base  => '__common.blog_name',
            label => sub {
                MT->app->blog
                    ? MT->translate('Blog Name')
                    : MT->translate('Website/Blog Name');
            },
            display   => 'default',
            site_name => sub { MT->app->blog ? 0 : 1 },
            order     => 99,
        },
        obj_type => {
            base    => '__virtual.string',
            label   => 'Target Object Type',
            order   => 100,
            display => 'default',
            col     => 'obj_type',
            auto    => 1,
        },
        obj_id => {
            base    => '__virtual.integer',
            label   => 'Target Object ID',
            order   => 101,
            display => 'optional',
            col     => 'obj_id',
            auto    => 1,
        },
        object => {
            label   => 'Target Object',
            order   => 102,
            display => 'default',
            html    => \&AjaxRating::CMS::list_prop_object_content,
        },
        score => {
            base    => '__virtual.float',
            label   => 'Score',
            order   => 200,
            display => 'default',
            col     => 'score',
        },
        created_by => {
            base    => '__virtual.author_name',
            label   => 'Created By',
            order   => 800,
            display => 'default',
            raw          => sub {
                my ( $prop, $obj ) = @_;
                my $col
                    = $prop->datasource->has_column('author_id')
                    ? 'author_id'
                    : 'created_by';

                # If there's no value in the column then no voter ID was
                # recorded.
                return '' if !$obj->$col;

                my $author = MT->model('author')->load( $obj->$col );
                return $author
                    ? ( $author->nickname || $author->name )
                    : MT->translate('*User deleted*');
            },
        },
        created_on => {
            base    => '__virtual.created_on',
            order   => 810,
            display => 'default',
        },
    };
}

1;
