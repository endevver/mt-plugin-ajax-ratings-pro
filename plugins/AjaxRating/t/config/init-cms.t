#!/usr/local/bin/perl

### TODO Check foreign object insertion

use Test::AjaxRating::Tools;
use Test::MT::Suite;
use List::MoreUtils qw( first_value );
use DDP { filters => {
    'MT::App::CMS' => sub { say 'App: ', $_[0] },
    'MT::Plugin' => sub { say $_[0]->id, ': ', $_[0] }
}};
$ENV{MT_APP} = my $App = 'MT::App::CMS';

my %marker = ();
my $suite = Test::MT::Suite->new({
    init_mocks => [
        [
            'AjaxRating', 'init_app', sub {
                ($marker{ar_init_app} ||= 0)++;
                Test::MT::Suite->instance
                    ->get_mock('AjaxRating')->original('init_app')->(@_);
            }
        ],
        [
            'AjaxRating::DataAPI::Callback::Init', 'init_app', sub {
                ($marker{ar_data_api_init_app} ||= 0)++;
                Test::MT::Suite->instance
                    ->get_mock('AjaxRating::DataAPI::Callback::Init')
                    ->original('init_app')
                    ->(@_);
            }
        ],
        [
            'AjaxRating::Upgrade::PLtoYAML', 'run', sub {
                $marker{pltoyaml} ||= 0;
                $marker{pltoyaml}++;
                Test::MT::Suite->instance
                    ->get_mock('AjaxRating::Upgrade::PLtoYAML')
                    ->original('run')->(@_);
            }
        ]
    ],
});

my $app;
subtest "Initialization" => sub {
    $app = load_class($App)->instance();
    isa_ok( $app, 'MT::App::CMS', 'App' );
    is( $marker{ar_init_app}, 1, 'AjaxRating::init_app' );
    is( $marker{pltoyaml}, 1, 'Init app PLtoYAML' );
    is( $marker{ar_data_api_init_app}, undef,
        'No Ajaxrating DataAPI init_app' );
};

subtest "List properties" => sub {
    my $list_props = MT->registry('list_properties');
    is( ref $list_props, 'HASH', 'list_properties is a HASH reference' );
    my @obj_types  = keys %{ AjaxRating->plugin->registry('object_types') };
    my %ds         = map { $_ => $app->model($_)->datasource } @obj_types;
    isnt($list_props->{$_}, undef, 'List props for '.$_)
        foreach %ds;
};

use AjaxRating::Util qw( obj_to_type );
subtest "obj_to_type" => sub {
    my $types = MT->registry('object_types');
    is( (obj_to_type( AjaxRating::Object::Vote->new() ))[0],
        'ajaxrating_vote', 'ajaxrating_vote' );
    is( (obj_to_type( AjaxRating::Object::VoteSummary->new() ))[0],
        'ajaxrating_votesummary', 'ajaxrating_votesummary' );
    is( (obj_to_type( AjaxRating::Object::HotObject->new() ))[0],
        'ajaxrating_hotobject', 'ajaxrating_hotobject' );
};

done_testing();


__END__

# use Time::HiRes qw( gettimeofday tv_interval );
# my %times = ();
# my $spec  = "%-26s %10s %-26s %s\n";
#
# my $types ||= MT->registry('object_types');
#
# note sprintf $spec, 'Type', 'Elapsed', 'Derived', 'Field(s)';
# foreach my $type ( MT->models() ) {
#     my $class = MT->model( $type );
#     my $obj   = $class->load(undef, { limit => 1 }) or next;
#     my $t0     = [gettimeofday];
#     my @return = obj_to_type( $obj, $types );
#     my $elapsed = tv_interval($t0);
#     $times{$type} = [ $elapsed, @return ];
# }
# note sprintf $spec, $_, @{$times{$_}} foreach sort keys %times;
#
# my ($total, $average) = (0,0);
# $total  += $times{$_}->[0] foreach keys %times;
# $average = $total / scalar(keys %times);
# say 'Total elapsed time: '.$total;
# say 'Average elapsed time: '.$average;

# Type                     Elapsed Derived                  Field(s)
# ReblogData               4.5e-05 ReblogData               object_types grep
# ReblogSourcefeed         3.4e-05 ReblogSourcefeed         object_types grep
# ajaxrating_hotobject     2.1e-05 ajaxrating_hotobject     object_types grep
# ajaxrating_vote          3.2e-05 ajaxrating_vote          object_types grep
# ajaxrating_votesummary   3.3e-05 ajaxrating_votesummary   object_types grep
# asset                    3.9e-05 file                     object_types grep
# asset.audio              5.5e-05 asset.audio              object_types grep
# asset.file               2.3e-05 file                     object_types grep
# asset.image              4.1e-05 image                    object_types grep
# asset.photo              2.6e-05 photo                    object_types grep
# asset.video              3.2e-05 video                    object_types grep
# association              3.4e-05 association              object_types grep
# audio                    2.9e-05 asset.audio              object_types grep
# author                   3.4e-05 commenter                object_types grep
# blog                     2.8e-05 site                     object_types grep
# blog.website               3e-05 blog.website             object_types grep
# bob_job                    6e-05 bob_job                  object_types grep
# category                 2.6e-05 category                 object_types grep
# category.folder          5.5e-05 category.folder          object_types grep
# comment                  4.6e-05 comment                  object_types grep
# commenter                3.6e-05 commenter                object_types grep
# config                   5.2e-05 config                   object_types grep
# entry                    8.5e-05 entry                    class_type
# entry.page               4.8e-05 page                     object_types grep
# field                    2.9e-05 field                    object_types grep
# file                     2.2e-05 file                     object_types grep
# fileinfo                   3e-05 fileinfo                 object_types grep
# filter                   3.1e-05 filter                   object_types grep
# folder                   2.9e-05 category.folder          object_types grep
# game_badge               3.5e-05 game_badge               object_types grep
# game_container           4.5e-05 game_container           object_types grep
# game_log                 2.9e-05 game_log                 object_types grep
# game_rule                4.1e-05 game_rule                object_types grep
# group                    2.4e-05 group                    object_types grep
# image                    3.4e-05 image                    object_types grep
# log                      3.5e-05 log                      object_types grep
# log.comment              4.1e-05 log.comment              object_types grep
# log.entry                3.5e-05 log.entry                object_types grep
# log.system               3.6e-05 log                      object_types grep
# objectasset                4e-05 objectasset              object_types grep
# objecttag                  4e-05 objecttag                object_types grep
# page                     4.8e-05 page                     object_types grep
# permission               4.6e-05 permission               object_types grep
# photo                    2.2e-05 photo                    object_types grep
# placement                2.1e-05 placement                object_types grep
# plugindata               2.7e-05 plugindata               object_types grep
# pp_choices               2.4e-05 pp_choices               object_types grep
# pp_questions             2.9e-05 pp_questions             object_types grep
# pp_votes                 5.1e-05 pp_votes                 object_types grep
# role                       3e-05 role                     object_types grep
# session                    3e-05 session                  object_types grep
# site                       3e-05 site                     object_types grep
# tag                        3e-05 tag                      object_types grep
# template                   6e-05 template                 object_types grep
# templatemap              2.2e-05 templatemap              object_types grep
# thumbnail_prototype      2.1e-05 thumbnail_prototype      object_types grep
# thumbnail_prototype_map  5.2e-05 thumbnail_prototype_map  object_types grep
# touch                    2.9e-05 touch                    object_types grep
# trackback                .000107 trackback                object_types grep
# ts_error                 2.5e-05 ts_error                 object_types grep
# ts_exitstatus            3.2e-05 ts_exitstatus            object_types grep
# ts_funcmap                 3e-05 ts_funcmap               object_types grep
# ts_job                   6.3e-05 ts_job                   datasource
# tw_message               5.2e-05 tw_message               object_types grep
# user                     2.7e-05 commenter                object_types grep
# video                    3.7e-05 video                    object_types grep
# website                  4.8e-05 blog.website             object_types grep
Total elapsed time: 0.002513
Average elapsed time: 3.75074626865672e-05

