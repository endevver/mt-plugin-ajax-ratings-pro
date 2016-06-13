#!/usr/local/bin/perl

### TODO Check foreign object insertion

use Test::AjaxRating::Tools;
use Test::MT::Suite;
use DDP { filters => {
    'MT::App::CMS' => sub { say 'App: ', $_[0] },
    'MT::Plugin' => sub { say $_[0]->id, ': ', $_[0] }
}};
$ENV{MT_APP} = my $App = 'MT::App::DataAPI';

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
    isa_ok( $app, 'MT::App::DataAPI', 'App' );
    is( $marker{ar_init_app}, 1, 'AjaxRating::init_app' );
    is( $marker{pltoyaml}, 1, 'Init app PLtoYAML' );
    is( $marker{ar_data_api_init_app}, 1,
        'Ajaxrating DataAPI init_app' );
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

my @ep_tests;
subtest "rateable_object_types" => sub {
    my $rateable = AjaxRating->rateable_object_types;
    foreach my $type ( sort keys %$rateable ) {
        my $plural = $rateable->{$type}{type_plural};
        subtest "$type" => sub {
            isnt( $type,   undef, "type" );
            isnt( $plural, undef, "type_plural" );
        };

        push( @ep_tests,
            {
                id             => "ar_${type}_fetch_summary",
                route          => "/ar/:$plural/:${type}_ids",
                default_params => superhashof({
                    id_param   => "${type}_ids",
                }),
            },
            {
                id             => "ar_${type}_list_votes",
                route          =>  "/ar/:$plural/:${type}_ids/list",
                default_params => superhashof({
                    id_param   => "${type}_ids",
                }),
            },
            {
                id             => "ar_${type}_add_vote",
                route          => "/ar/:$plural/:${type}_id/vote",
                default_params => superhashof({
                    id_param   => "${type}_id"
                }),
            },
            {
                id             => "ar_${type}_fetch_vote",
                route          => "/ar/:$plural/:${type}_ids/vote",
                default_params => superhashof({
                    id_param   => "${type}_ids",
                }),
            },
            {
                id             => "ar_${type}_remove_vote",
                route          => "/ar/:$plural/:${type}_ids/vote",
                default_params => superhashof({
                    id_param   => "${type}_ids"
                }),
            },
        )
    }
};

subtest "Object endpoints" => sub {
    foreach my $ep_test ( @ep_tests ) {
        my $ep = $app->find_endpoint_by_id( 1, $ep_test->{id} );
        cmp_deeply( $ep, superhashof($ep_test), 'Endpoint: '.$ep_test->{id} );

    }
};

done_testing();

__END__
