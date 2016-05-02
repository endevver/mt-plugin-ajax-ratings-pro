package Test::AjaxRating::Suite {

    use Test::AjaxRating::Tools;
    use integer;

    BEGIN {
        eval { require Test::MockModule }
            or plan skip_all => 'Test::MockModule is not installed';
        # eval { require Test::MockTime; import Test::MockTime qw( :all ); 1 }
        #     or plan skip_all => 'Test::MockTime is not installed';
    }

    BEGIN {
        if ( $ENV{MT_HOME} && ! $ENV{MT_CONFIG} ) {
            my $cfg = path( $ENV{MT_HOME}, 'mt-config.cgi' );
            say STDERR "MT_CONFIG not defined. Using $cfg "
                     . "and disabling DB reinitialization" unless $^C || !$^W;
            $ENV{MT_CONFIG}                  = $cfg;
            $ENV{SKIP_REINITIALIZE_DATABASE} = 1;
        }

        my $current_user = getpwuid($<);
        $ENV{DATAPRINTERRC} = "".path(
            ( $current_user =~ m{(jay|allenjrj)} ? $ENV{HOME} : $ENV{MT_HOME} ),
            '.dataprinter'
        );

        $ENV{PERL_JSON_BACKEND} = "JSON::PP";

        $ENV{TZ} = 'America/Los_Angeles';

        $ENV{ENABLE_CACHE}
            || load_class('Data::ObjectDriver::Driver::BaseCache')->Disabled(1);
               # MT->config->ObjectCacheLimit
    }
    use Data::Printer colored => 0, rc_file => $ENV{DATAPRINTERRC};

    eval(
        $ENV{SKIP_REINITIALIZE_DATABASE}
        ? "use MT::Test qw(:app);"
        : "use MT::Test qw(:app :db :data);"
    );

    sub new {
        my $class = shift;
        $class = ref $class if ref $class;
        my $self = bless { ref($_[0]) eq 'HASH' ? %{$_[0]} : @_ }, $class;
        # __PACKAGE__->install_callbacks();
        $self->mock_object_load();

        $self->{mock_mt} = Test::MockModule->new('MT');
        $self->{mock_mt}->mock(
            'run_callbacks',
            sub {
                my ( $app, $meth, @param ) = @_;
                my $callbacks = $self->callbacks();
                $callbacks->{$meth} ||= [];
                # say STDERR "Running callback $meth"
                #     if $meth =~ m{(MT::App::DataAPI|init_request)};
                push @{ $callbacks->{$meth} }, \@param;
                $self->{mock_mt}->original('run_callbacks')->(@_);
            }
        );
        # $self->{mock_author}  = Test::MockModule->new('MT::Author');
        # $self->{mock_author}->mock(  'is_superuser', sub {0} );
        $self->{mock_app_api} = Test::MockModule->new($self->app_class);
        $self->{mock_app_api}->mock( 'authenticate', sub {
            my $user = $self->author;
            if ( !$user || $user->is_anonymous || ! $user->name ) {
                note '  REQUEST unauthenticated (ANONYMOUS)';
            }
            else {
                note '  REQUEST authenticated as '.$user->name
                   . ( $user->is_superuser ? ' (SUPERUSER)' : '' );
            }
            $user;
        });
        $self;
    }

    sub install_callbacks {
        my $self   = shift;
        my $plugin = MT->component("ajaxrating");

        my $pre = sub {
            my ( $cb, $class, $terms, $args ) = map { $_ // {} } @_;
            say "Callback: ".$cb->name;
            my $debug = delete $args->{debug};
            unless ( $debug ) {
                if ( exists $ENV{DOD_DEBUG_ORIG} ) {
                    $ENV{DOD_DEBUG} = $Data::ObjectDriver::DEBUG
                                    = delete $ENV{DOD_DEBUG_ORIG};
                }
                return;
            }

            $ENV{DOD_DEBUG_ORIG} //= $Data::ObjectDriver::DEBUG
                                  || $ENV{DOD_DEBUG};
            $Data::ObjectDriver::DEBUG = $ENV{DOD_DEBUG} = 1;

            ref($debug) eq 'CODE'
                ? $debug->(@_)
                : sub { p @{[$class,{terms=>$terms},{args=>$args}]} };
        };
        MT->add_callback('*::pre_search', 10, $plugin, $pre );
    }

    sub dod_debug {
        my $self   = shift;
        my $driver = shift;
        return unless $Data::ObjectDriver::DEBUG & 2;
        my $class = ref $driver || $driver;
        my @caller = $self->get_caller( skip => $class );
        my $where = "D::OD debug called in line $caller[2] of $caller[1]\n";
        $driver->logger->(
            $where,
            ( @_ == 1 && !ref($_[0])) ? @_ : np(@_, caller_info => 0 )
        );
    }

    sub get_caller {
        my ( $self, %args ) = @_;
        my $skip = [];
        unless ( $args{no_skip} ) {
            $skip = ref $args{skip} ? $args{skip} : [ $args{skip} // () ];
            push( @$skip, qw( Data::ObjectDriver MT::Object ),
                          __PACKAGE__, ref($self)||$self );
        }

        my $excluded = join( '|', keys %{{ map { $_ => 1 } @$skip }} );
        $excluded    = qr/^$excluded/ if $excluded;
        my ( $i, @caller ) = ( 0 );
        while (1) {
            @caller = caller($i++);
            last if $excluded and $caller[0] !~ $excluded;
        }
        @caller;
    }

    sub mock_object_load {
        my $self = shift;
        $self->{mock_dod} = Test::MockModule->new('Data::ObjectDriver');
        $self->{mock_dod}->mock('debug', sub { $self->dod_debug(@_) });

        my $bo = $self->{mock_baseobj}
               = Test::MockModule->new('Data::ObjectDriver::BaseObject');
        $self->{mock_baseobj}->mock( 'search', sub {
            my ( $class, $terms, $args ) = map { $_ // {} } @_;
            my $debug     = delete $args->{debug};
            my $wantarray = wantarray ? 1 : 0;
            my $return    = sub {
                return $wantarray ? ( $bo->original('search')->( @_ ) )
                                  : scalar $bo->original('search')->( @_ );
            };

            unless ( $debug ) {
                if ( exists $ENV{DOD_DEBUG_ORIG} ) {
                    $ENV{DOD_DEBUG} = $Data::ObjectDriver::DEBUG
                                    = delete $ENV{DOD_DEBUG_ORIG};
                }
                return $return->( @_ );
            }

            my @caller = $self->get_caller;

            if ( ref($debug) eq 'CODE' ) {
                $debug->( \@caller, @_ );
                return $return->( @_ );
            }

            if ( $debug & 1 ) {
                printf STDERR
                    "pre_search debug called in line %d of %s",
                    $caller[2], $caller[1];
                p(@{[$class,{terms=>$terms},{args=>$args}]}, caller_info=>0);
            }

            if ( $debug & 2 ) {
                $ENV{DOD_DEBUG_ORIG} //= $Data::ObjectDriver::DEBUG
                                      || $ENV{DOD_DEBUG};
                $Data::ObjectDriver::DEBUG = $ENV{DOD_DEBUG} = $debug;
            }

            return $return->( @_ );
        });
    }

    sub app_class {
        my $self = shift;
        $self->{app_class}
            = $ENV{MT_APP} || $self->{app_class} || 'MT::App::DataAPI';
    }

    sub callbacks {
        my $self = shift;
        $self->{callbacks} = shift() if @_;
        return $self->{callbacks} //= {};
    }

    sub reset_callbacks {
        my $self = shift;
        return $self->callbacks({});
    }

    sub author {
        my $self        = shift;
        $self->{author} = $self->get_author( @_ ) if @_;
        $self->{author};
    }

    sub get_author {
        my ( $self, $arg ) = @_;
        state $Author = MT->instance->model('user');

        croak 'Invalid argument '.(defined($arg) ? $arg : 'UNDEFINED')
            unless $arg;

        return $arg if Scalar::Util::blessed( $arg ) && $arg->isa( $Author );

        my $terms = looks_like_number( $arg ) ? $arg : { name => $arg };
        my $user  = $Author->load($terms)
            or BAIL_OUT( sprintf( 'Could not load %s "%s": ', $Author, $arg,
                            $Author->errstr || np($terms, caller_info => 0 )));
    }

    sub default_author {
        my $self = shift;
        state $author = $self->get_author('rosiakr');
        return $author;
    }

    sub blog {
        my ( $self, $arg ) = @_;
        MT->instance->blog( $self->{blog} = $self->get_blog( $arg ) ) if $arg;
        $self->{blog};
    }

    sub get_blog {
        my ( $self, $arg ) = @_;
        state $Blog = MT->instance->model('blog');

        croak 'Invalid argument '.(defined($arg) ? $arg : 'UNDEFINED')
            unless $arg;

        return $arg if Scalar::Util::blessed( $arg ) && $arg->isa( $Blog );

        my $terms = $arg;
        unless ( looks_like_number( $terms ) ) {
            my $map = $self->blog_map();
            $terms  = exists($map->{$arg}) ? $map->{$arg} : { name => $arg };
        }
        my $blog = $Blog->load( $terms )
            or BAIL_OUT(sprintf('Could not load %s "%s": %s', $Blog, $arg,
                            $Blog->errstr||np($terms, caller_info => 0 )));
    }

    sub blog_map {
        my $self = shift;
        state $blog_map = GenentechThemePack::Util::blog_map();
        $blog_map;
    }

    sub tests {
        my $self = shift;
        $self->{tests} ||= [];
        return @_ ? ( $self->{tests} = shift() ) : $self->{tests};
    }

    sub add_test {
        my $self  = shift;
        my $test  = shift or croak "add_test argument is undefined";
        $self->tests([ @{$self->tests}, $test ]);
    }

    sub test_authors {
        my $self = shift;
        return (
            MT->instance->model('user')->anonymous,
            (
                map { $self->get_author($_) }
                    qw( allenjrj watonn rosiakr willimla )
            ),
        );
    }

    sub run {
        my $self  = shift;
        my $suite = $self->tests or die "No tests specified";
        my $format = MT::DataAPI::Format->find_format('json');

        for my $data (@$suite) {
            my $callbacks = $self->reset_callbacks();

            $data->{setup}->($data) if $data->{setup};
            my $path = $data->{path};
            $path
                =~ s/:(?:(\w+)_id)|:(\w+)/ref $data->{$1} ? $data->{$1}->id : $data->{$2}/ge;

            my $params
                = ref $data->{params} eq 'CODE'
                ? $data->{params}->($data)
                : $data->{params};

            delete $self->{author};

            my ( $user, $username );
            if ( my $author = $data->{author} ) {
                $user = $self->author( $author );
                $username = $user->name;
            }
            else {
                $username = 'unauthenticated';
                $user = $self->author( MT->instance->model('user')->anonymous );
                # MT->instance->permissions(undef);
            }

            my $req = join( ' ', $data->{method}, $path );
            if ( lc $data->{method} eq 'get' && $params ) {
                $req .= '?'
                    . join( '&',
                    map { $_ . '=' . $params->{$_} }
                        keys %$params );
            }

            my ( $headers, $body );
            subtest $data->{note} // $req => sub {
                note("  $req") if $data->{note};

                my $app = MT::Test::_run_app(
                    $self->app_class,
                    {   __path_info      => $path,
                        __request_method => $data->{method},
                        ( $data->{upload} ? ( __test_upload => $data->{upload} ) : () ),
                        (   $params
                            ? map {
                                $_ => ref $params->{$_}
                                    ? MT::Util::to_json( $params->{$_} )
                                    : $params->{$_};
                                }
                                keys %{$params}
                            : ()
                        ),
                    }
                );
                my $out = delete $app->{__test_output};
                ( $headers, $body ) = split /^\s*$/m, $out, 2;
                my %headers = map {
                    my ( $k, $v ) = split /\s*:\s*/, $_, 2;
                    $v =~ s/(\r\n|\r|\n)\z//;
                    lc $k => $v
                    }
                    split /\n/, ($headers//'');
                my $expected_status = $data->{code} || 200;
                is( $headers{status}, $expected_status,
                    'Status ' . $expected_status )
                    || do {
                        diag "RESPONSE BODY: ".$body;
                        $data->{response_bad_status} = 1;
                    };
                if ( $data->{next_phase_url} ) {
                    like(
                        $headers{'x-mt-next-phase-url'},
                        $data->{next_phase_url},
                        'X-MT-Next-Phase-URL'
                    );
                }

                foreach my $cb ( @{ $data->{callbacks} } ) {
                    $cb = { name => $cb, count => 1 } unless ref $cb eq 'HASH';
                    my $params_list = $callbacks->{ $cb->{name} } || [];
                    if ( my $params = $cb->{params} ) {
                        for ( my $i = 0; $i < scalar(@$params); $i++ ) {
                            is_deeply( $params_list->[$i], $cb->{params}[$i] );
                        }
                    }
                    if ( my $c = $cb->{count} ) {
                        is( @$params_list, $c,
                            $cb->{name} . ' was called ' . $c . ' time(s)' );
                    }
                }

                my $expected = $data->{result};
                if ( $expected ) {
                    # p $expected;
                    if ( ref $expected eq 'CODE' ) {
                        $expected = $expected->( $data, $body )
                    }

                    if ( UNIVERSAL::isa( $expected, 'MT::Object' ) ) {
                        MT->instance->user($self->author) if $self->author;
                        $expected = $format->{unserialize}->(
                            $format->{serialize}->(
                                MT::DataAPI::Resource->from_object($expected)
                            )
                        );
                    }
                    $ENV{DEBUG_RESULT} && p $expected;
                }

                my $cmp_method = $data->{result_test}
                              // $data->{result_method}
                              // ( $expected ? 'is_deeply' : '' );
                if ( $cmp_method and ref($cmp_method) ne 'CODE' ) {
                    no strict 'refs';
                    my $meth    = $cmp_method;
                    $meth       = \&$meth if defined &$meth;
                    $meth     ||= $self->can($meth);
                    $cmp_method = $meth;
                }

                if ( $cmp_method ) {
                    my $got   = $format->{unserialize}->($body);
                    my $label = 'result: '.($data->{note} ? $data->{note} : '');
                    my @args  = ( $got, $expected, $label );
                    if ( $data->{result_test} ) {
                        $cmp_method->( @args, $data );
                    }
                    else {
                        $cmp_method->( @args )
                            or diag explain
                                {got => $got, expected => $expected};
                    }
                }
            };

            $data->{complete} && $data->{complete}->( $data, $body );
        }
    }

    # These properties are required by MT::Entry
    sub required_entry_props { return (qw( title blog_id author_id )) }

    # These properties are exclusive. The latter are recognized and handled
    # by this module in order to allow for naming authors and categories
    # by name/label instead of ID
    sub exclusive_entry_props {
        return (
            blog     => [qw( blog_id blog )],
            author   => [qw( author_id author )],
            category => [qw( category_id category categories )],
        );
    }

    sub default_tags {
        my ( $self, $level ) = ( @_, 1 );
        state $pkg = __PACKAGE__ =~ s{::}{-}gr;
        return ( 'perltest',  $pkg, $self->script_basename );
    }

    sub default_title { $_[0]->test_title( 'Default title' ) }

    sub test_title {
        my ( $self, @title ) = @_;
        $self->{current_entry_title}
            = join( ' ', $self->script_basename, @title,
                         $self->script_entry_counter(), $$, $self->script_ts );
    }

    sub last_title { $_[0]->{current_entry_title} }

    sub script_entry_counter {
        state $count = 0;
        $count++;
    }

    sub script_ts {
        state $ts = time();
        return $ts;
    }

    sub script_basename {
        state $script = basename($0);
        return $script;
    }

    sub prepare_entry_data {
        my ( $self, %data ) = @_;
        my $Entry           = MT->instance->model('entry');

        ### EXCLUSIVE_ENTRY_PROPS
        ### Make sure that only one is specified to avoid conflicts
        my $defined_check   = sub {
            my $k = shift;
            return
                ! exists($data{$k})  ? 0
                : defined($data{$k}) ? 1
                                     : do { warn("Ignoring undefined $k"); 0 };
        };
        my %exclusive = $self->exclusive_entry_props;
        foreach my $type ( keys %exclusive ) {
            my @args = grep { $defined_check->($_) } @{ $exclusive{$type} };
            my $arg  = shift @args or next;
            @args and die "Multiple $type arguments specified: "
                        . join(', ', sort($arg, @args));
            $data{$type} = delete $data{$arg};
        }

        ### SET DEFAULTS FOR EXPANSION PROPERTIES
        $data{blog}        ||= MT->instance->blog;
        $data{author}      ||= $self->default_author;

        ### EXPAND BLOG AND AUTHOR TO OBJECTS
        foreach my $type (qw( blog author )) {
            next unless $data{$type};
            my ( $meth, $arg ) = ( "get_$type", $data{$type} );
            $data{$type}       = $self->$meth( $arg )
                or die sprintf '%s::%s: Cannot load %s %s',
                             __PACKAGE__, 'prepare_entry_data', $arg;
            $data{$type.'_id'} = $data{$type}->id;
        }

        ### EXPAND CATEGORIES TO OBJECTS
        if ( my $cats = delete $data{category} ) {
            $data{categories} = [
                map { $self->get_blog_category($_, $data{blog_id}) }
                    @{ ref($cats) eq 'ARRAY' ? $cats : [ $cats ] }
            ];
        }

        ### SET OTHER DEFAULTS
        $data{title}       ||= $self->default_title();
        $data{status}      ||= $Entry->RELEASE();
        $data{authored_on} ||= $data{blog}->current_timestamp;

        ### ADD EXTRA TAGS FOR EASY ENTRY DELETION FROM TESTS
        $data{tags} = [ @{ $data{tags} || [] }, $self->default_tags ];

        ### PARTITION DATA BETWEEN NATIVE COLUMNS AND CUSTOM FIELDS
        my ( $meta, $props, @other )
            = part {  $Entry->is_meta_column("field.$_") ? 0
                    : $Entry->has_column($_)             ? 1
                                                         : 2
                   } keys %data;

        $data{$_} ||= {} for qw( cols meta );

        $data{cols}{$_->[0]}  = $_->[1]
            foreach grep { defined($_->[1]) }
                    map  { [ $_ => delete $data{$_} ] } @$props;

        $data{meta}{$_->[0]} = $_->[1]
            foreach grep { defined($_->[1]) }
                    map  { [ $_ => delete $data{$_} ] } @$meta;

        ### GWIZ-SPECIFIC DATA TWEAKS
        $data{meta}{event1_start} = $data{cols}{authored_on}
            if $data{blog}->name eq 'Events';

        ### CHECK REQUIRED PROPERTIES FROM NATIVE COLUMNS
        my @undefined
            = grep { ! defined($data{cols}{$_}) } $self->required_entry_props;
        if ( @undefined ) {
            croak "The following required properties are undefined: "
                . join(', ', @undefined);
        }

        ### REMOVE ANY UNDEFINED PROPERTIES
        foreach my $h ( \%data, $data{cols}, $data{meta} ) {
            next unless $h;
            delete $h->{$_} for grep { ! defined($h->{$_}) } keys %$h;
        }

        $ENV{DEBUG} && p(%data);
        return \%data;
    }

    sub create_entry {
        my $self  = shift;
        my $data  = $self->prepare_entry_data( @_ );
        my $Entry = MT->instance->model('entry');
        my $entry = $Entry->new();

        $entry->set_values( $data->{cols} );

        $entry->meta( "field.$_", $data->{meta}{$_} )
            foreach map { s{^field.}{}r } keys %{$data->{meta} || {}};

        $entry->add_tags( @{$data->{tags}} ) if $data->{tags};

        return $entry if $data->{no_save};

        $entry->save or die "Could not save entry: ".$Entry->stderr;

        $entry->attach_categories( @{$data->{categories}} )
            if $data->{categories};

        $entry->clear_cache();

        return $entry;
    }

    sub cmp_entries {
        my $self = shift;
        my ( $got, $expected, $methods ) = @_;
        $methods = [
            (ref($methods) ? @$methods : $methods ? $methods : ()),
            qw( id atom_id author_id authored_on basename blog_id
                created_on modified_on permalink status title
                categories tags ),
        ];
        my $Entry = MT->instance->model('entry');

        # Partition out the metafields
        my ( $meta_methods ) = [];
        ( $methods, $meta_methods )
            = part { $Entry->is_meta_column("field.$_") ? 1 : 0 } @$methods;

        # Convert to hashes to dedupe
        my %meta_methods = map { $_ => 1 } @$meta_methods;
        my %methods      = map { $_ => 1 } @$methods;
        my $meth_cnt     = scalar(keys(%methods)) + scalar(keys(%meta_methods));

        is( scalar @$got, scalar @$expected, "got/expected counts" );

        my $safevals = sub {
            my ( $key, $a, $b ) = @_;
            return (
                ( defined($a) ? $a->$key : '' ),
                ( defined($b) ? $b->$key : '' ),
            );
        };

        my $cnt = 0;
        my $iter = each_arrayref( $got, $expected );
        while ( my ( $g, $e ) = $iter->() ) {
            subtest 'Entry '.$cnt++.' comparison' => sub {
                my $isa_ok =  isa_ok( $g, $Entry, 'Got' )
                           && isa_ok( $e, $Entry, 'Expected' );
                MISSING: {
                    skip 'Missing object', 2 unless $isa_ok;
                    my $id_ok  = is( $g->id, $e->id, 'id' );
                    SKIP: {
                        skip 'Entry mismatch', ( $meth_cnt - 1 ) unless $id_ok;

                        foreach my $col ( sort keys %methods ) {
                            if ( $col =~ m{(tags|categories)} ) {
                                cmp_bag( [$g->$col], [$e->$col], $col );
                            }
                            else {
                                is( $g->$col, $e->$col, $col );
                            }
                        }

                        foreach my $col ( sort keys %meta_methods ) {
                            my $field = "field.$col";
                            is( $g->meta($field), $e->meta($field), $field );
                        }
                    }
                }
            };
        }
    }

    sub entry_meta_join {
        my $self = shift;
        my ( $k, $v ) = ( @_, 1 );
        my $Entry = MT->instance->model('entry');
        my $type  = MT::Meta->metadata_by_name( $Entry, "field.$k" );
        return (
            join => $Entry->meta_pkg->join_on( 'entry_id',
                        {type => 'field.'.$k, $type->{type} => $v} )
        );
    }

    sub clone {
        my $self = shift;
        unless ( @_ == 1 and ref($_[0]) ) {
            croak 'clone takes a single scalar argument. '
                . 'Please pass arrays and hashes as references.';
        }
        require Clone;
        Clone::clone(+shift);
    }
}

1;
