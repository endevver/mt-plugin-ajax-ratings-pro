package Test::AjaxRating::Tools {

    use strict;
    use warnings;
    use 5.016;
    use base 'ToolSet';

    # die "MT_HOME not set" unless $ENV{MT_HOME};
    my $dataprinter_cfg
        = "output=>'stderr',colored=>0,caller_info=>1,deparse=>1,"
        . "filters => { 'MT::App::DataAPI' => sub{ \$_[0] }, 'MT::Plugin' => sub{ \$_[0] }, 'MT::App::CMS' => sub{ \$_[0] }, 'AjaxRating::App::AddVote' => sub{ \$_[0] }, 'AjaxRating::App::GetVotes' => sub{ \$_[0] }, 'AjaxRating::App::ReportComment' => sub{ \$_[0] } }"
        . ($ENV{DATAPRINTERRC} ? ", rc_file=>'".$ENV{DATAPRINTERRC}."'" : '' );

    ToolSet->use_pragma('strict');
    ToolSet->use_pragma('warnings');
    ToolSet->use_pragma( 'lib', map { ($ENV{MT_HOME}||'.')."/$_" }
                                    qw( plugins/AjaxRating/t/lib
                                        plugins/AjaxRating/lib
                                        lib extlib ) );
    ToolSet->use_pragma('feature', ':5.16');  # so push/pop/etc work on scalars

    ToolSet->export(
        'Test::More'                 => undef,
        'Path::Tiny'                 => undef,
        'File::Find'                 => undef,
        'File::Basename'             => 'basename dirname',
        'File::Temp'                 => 'tempdir',
        'Try::Tiny'                  => undef,
        'Class::Load'                => 'load_class',
        'URI'                        => undef,
        'REST::Client'               => undef,
        'URI::URL'                   => 'url',
        'List::MoreUtils'            => 'first_value firstval first_result part each_arrayref',
        'Test::Deep'                 => ':v1', # No blessed, isa or Isa exports
        'Scalar::Util'               => 'blessed looks_like_number',
        'Carp'                       => 'carp croak confess longmess',
        'Carp::Always'               => undef,
        # 'Log::Log4perl::Resurrector' => undef,
        # 'MT::Logger::Log4perl'       => 'get_logger l4mtdump :resurrect',
        'Data::Printer'              => \"$dataprinter_cfg",
        # 'MT'                         => undef,
    );
};

1;

__END__
