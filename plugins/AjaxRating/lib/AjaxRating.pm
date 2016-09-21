#########################################################

package AjaxRating;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use Try::Tiny;
use List::MoreUtils  qw( first_result first_value );
use Scalar::Util     qw( blessed looks_like_number );
use MT;
use MT::Util         qw( epoch2ts );
use AjaxRating::Util qw( get_config pluralize_type );
# use DDP {
#     caller_info => 1,
#     filters => {
#         'MT::App::CMS' => sub { say 'App: ', $_[0] },
#         'MT::Plugin'   => sub { say $_[0]->id, ': ', $_[0] }
#     }
# };

sub plugin { return MT->component('ajaxrating') }

sub post_init { require AjaxRating::Types; AjaxRating::Types->init( @_ ) }

sub init_app {
    my ( $plugin, $app ) = @_;

    require AjaxRating::Upgrade::PLtoYAML;
    AjaxRating::Upgrade::PLtoYAML::run( @_ );

    if ( $app->id eq 'data_api' ) {
        require AjaxRating::DataAPI::Callback::Init;
        AjaxRating::DataAPI::Callback::Init::init_app( @_ );
    }
}

sub listing {
    my ( $ctx, $args ) = @_;

    # DEFAULTS
    my %list_terms = ( obj_type => $args->{type} || 'entry' );
    my %list_args  = (
        # TODO Figure out what start_val does. See MT::ObjectDriver::Driver::DBI
        start_val => 0,
        sort      => 'total_score',
        limit     => $args->{show_n} // 10,
        direction => ($args->{sort_order}||'') eq 'ascend' ? 'ascend'
                                                           : 'descend',
    );

    given ( $args->{sort_by} || '' ) {
        when ( /vote/ )        { $list_args{sort} = 'vote_count'  }
        when ( /av(g|erage)/ ) { $list_args{sort} = 'avg_score'   }
    }

    # Handle obj_type variance with TB pings
    $list_terms{obj_type} =~ s{^trackback$}{ping};
    my $obj_type          = $list_terms{obj_type};

    # blogs or blog_id can be undef, a single ID, CSV IDs or 'all'
    if ( my $blogs = $args->{blogs} || $args->{blog_id} || '' ) {
        unless ( $blogs eq 'all' ) {  # Don't set blog_id term
            my @blogs            = split( /\s*,\s*/, $blogs );
            $list_terms{blog_id} = @blogs > 1 ? \@blogs : $blogs[0];
        }
    }
    else {  # undef means the blog in context
        $list_terms{blog_id} = $ctx->stash('blog_id');
    }

    require MT;
    my $class        = MT->model( $obj_type );
    my $rating_type  = $args->{hot} ? 'hotobject' : 'votesummary';
    my $rating_class = MT->model( 'ajaxrating_'.$rating_type );
    my @summaries    = $rating_class->load(\%list_terms, \%list_args);

    my $i       = 0;
    my $res     = '';
    my $limit   = $list_args{limit};
    my $vars    = $ctx->{__stash}{vars} ||= {};
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    foreach my $vsumm (@summaries) {
        if ( my $obj = $class->load($vsumm->obj_id) ) {
            $i++;
            my $last = 1 if $i >= $limit or ! defined $summaries[$i];
            $ctx->stash( $obj_type, $obj );
            my $blog = MT->model('blog')->load( $obj->blog_id );
            $ctx->stash( 'blog_id', $blog->id );
            $ctx->stash( 'blog',    $blog     );
            local $vars->{__first__}   = $i == 1;
            local $vars->{__last__}    = $last;
            local $vars->{__odd__}     = ($i % 2) == 1;
            local $vars->{__even__}    = ($i % 2) == 0;
            local $vars->{__counter__} = $i;
            defined(my $out = $builder->build($ctx, $tokens))
                or return $ctx->error($builder->errstr);
            $res .= $out;
        } else {
            $vsumm->remove or warn sprintf(
                'Could not remove %s ID %d on %s ID %d: %s',
                    blessed($_), $_->id, $_->obj_type, $_->obj_id,
                    ($_->errstr||'unknown error') );
        }
    }
    $res;
}

sub listing_entries     { $_[1]->{type} = 'entry';     listing(@_) }
sub listing_comments    { $_[1]->{type} = 'comment';   listing(@_) }
sub listing_pings       { $_[1]->{type} = 'trackback'; listing(@_) }
sub listing_categories  { $_[1]->{type} = 'category';  listing(@_) }
sub listing_blogs       { $_[1]->{type} = 'blog';      listing(@_) }
sub listing_authors     { $_[1]->{type} = 'author';    listing(@_) }
sub listing_tags        { $_[1]->{type} = 'tag';       listing(@_) }

# Return the number of votes for each score number on an object.
sub listing_vote_distribution {  ### TODO Review this; UNDOCUMENTED TAG
    my ( $ctx, $args, $cond ) = @_;

    my %obj_info = object_from_args(@_) or return;
    my ( $obj_type, $obj_id, $obj ) = map { $obj_info{$_} }
                                            qw( obj_type obj_id obj );

    # Load the summary for this object.
    my $terms = { obj_type => $obj_type, obj_id => $obj_id };
    $terms->{blog_id}   = $args->{blog_id}       if $args->{blog_id};
    $terms->{blog_id} ||= $ctx->stash('blog_id') if $ctx->stash('blog_id');

    my $vsumm = MT->model('ajaxrating_votesummary')->load($terms)
        or return '';

    # Read the saved YAML vote_distribution, and convert it into a hash.
    # If there is no vote_distribution data, we need to create it. This should
    # have been done during the upgrade already.
    my $yaml = $vsumm->compile_vote_dist();

    # Load the entry_max_points or comment_max_points config setting
    # (depending upon the object type), or just fall back to the value 10.
    # 10 is used as a fallback elsewhere for the max points, so it's a safe
    # guess that it's good to use.
    my $max_points = get_config(
        ( $vsumm->blog_id // $obj->blog_id ),
        ( $vsumm->obj_type // $obj_type ) . '_max_points'
    ) || '10';

    # Make sure that all possible scores have been marked--at least with a 0.
    # The default value is set here (as opposed to in the foreach that outputs
    # the values) so that different types of raters (which may have positive
    # or negative values) don't get confused.
    my $count = 1;
    while ( $count <= $max_points ) {
        $yaml->[0]->{$count} = '0' if !$yaml->[0]->{$count};
        $count++;
    }

    my $out = '';
    my $vars = $ctx->{__stash}{vars};
    $count = 0;
    foreach my $score ( sort keys %{$yaml->[0]} ) {
        local $vars->{score}       = $score;
        local $vars->{vote}        = $yaml->[0]->{$score};
        local $vars->{__first__}   = ( $count++ == 0 );
        local $vars->{__last__}    = ( $count == $yaml->[0] );
        local $vars->{__odd__}     = ($count % 2) == 1;
        local $vars->{__even__}    = ($count % 2) == 0;
        local $vars->{__counter__} = $count;

        defined( $out .= $ctx->slurp( $args, $cond ) ) or return;
    }
    return $out;
}

sub ajax_rating {
    my ($ctx, $args) = @_;

    my %obj_info = object_from_args(@_) or return;
    my ( $obj_type, $obj_id, $obj ) = map { $obj_info{$_} }
                                            qw( obj_type obj_id obj );

    my $terms = { obj_type => $obj_type, obj_id => $obj_id };
    my $vsumm = MT->model('ajaxrating_votesummary')->load($terms)
        or return 0;

    my $show     = defined($args->{show}) ? $args->{show} : 'total_score';
    return $show =~ m{^(avg_score|vote_count)$} ? $vsumm->$show
                                                : $vsumm->total_score;
}

sub ajax_rating_avg_score   { $_[1]->{show} = 'avg_score';  ajax_rating(@_) }
sub ajax_rating_vote_count  { $_[1]->{show} = 'vote_count'; ajax_rating(@_) }
sub ajax_rating_total_score { ajax_rating(@_)                               }

# Return the number of votes on Entries in the current blog.
sub ajax_rating_total_votes_in_blog {
    my ( $ctx, $args ) = @_;
    my $terms = { blog_id  => $ctx->stash('blog_id'),
                  obj_type => $args->{type} || 'entry' };
    return MT->instance->model('ajaxrating_vote')->count($terms) || 0;
}

sub ajax_rating_user_vote_count {
    my ( $ctx, $args ) = @_;
    my $author = context_author(@_) or return;
    my $terms  = { voter_id => $author->id,
                   obj_type => $args->{obj_type} || 'entry' };
    return MT->model('ajaxrating_vote')->count($terms) || 0;
}

sub listing_user_votes {
    my ($ctx, $args, $cond) = @_;
    my $author    = context_author(@_) or return;
    my $obj_type  = $args->{obj_type}  || 'entry';
    my $lastn     = $args->{lastn}     || 10;
    my $sort_by   = $args->{sort_by}   || 'authored_on';
    my $direction = $args->{direction} || 'descend';
    my $offset    = $args->{offset}    || 0;
    my $blog_id   = $args->{blog_id};
    my $vterms    = { voter_id => $author->id, obj_type => $obj_type,
                      ( $blog_id ? (blog_id => $blog_id) : () ) };
    my $vargs     = { limit => $lastn,      offset    => $offset,
                      sort => 'created_on', direction => $direction };
    my @votes = MT->model('ajaxrating_vote')->load( $vterms, $vargs )
        or return MT::Template::Context::_hdlr_pass_tokens_else(@_);

    my $res     = '';
    my $i       = 0;
    my $tok     = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my $glue    = $args->{glue};
    my $vars    = $ctx->{__stash}{vars} ||= {};
    foreach my $vote (@votes) {
        my $e = MT->model($obj_type)->load($vote->obj_id) or next;
        local $vars->{__first__}             = !$i;
        local $vars->{__last__}              = !defined $votes[$i+1];
        local $vars->{__odd__}               = ($i % 2) == 0; # 0-based $i
        local $vars->{__even__}              = ($i % 2) == 1;
        local $vars->{__counter__}           = $i+1;
        local $ctx->{__stash}{blog}          = $e->blog;
        local $ctx->{__stash}{blog_id}       = $e->blog_id;
        local $ctx->{__stash}{entry}         = $e;
        local $ctx->{current_timestamp}      = $e->authored_on;
        local $ctx->{current_timestamp_end}  = $e->authored_on;
        local $ctx->{modification_timestamp} = $e->modified_on;
        my $out                              = $builder->build($ctx, $tok);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $glue if defined $glue && $i && length($res) && length($out);
        $res .= $out;
        $i++;
    }
    return $res;
}

sub star_rater       { $_[1]->{rater_type} = 'star';       rater(@_)      }
sub thumb_rater      { $_[1]->{rater_type} = 'thumb';      rater(@_)      }
sub rater_onclick_js { $_[1]->{rater_type} = 'onclick_js'; rater(@_)      }

sub entry_max   { get_config( shift()->stash('blog'), 'entry_max_points'   )}
sub comment_max { get_config( shift()->stash('blog'), 'comment_max_points' )}

sub star_rater_width {
    my ( $ctx, $args )  = @_;
    my $max_setting     = ($args->{type} || 'entry') . '_max_points';
    my ( $max, $width )
        = get_config( $ctx->stash('blog'), $max_setting, 'unit_width');
    return ($max||0) + ($width||0);
}

sub star_rater_avg_score_width {
    my ( $ctx, $args ) = @_;
    my $max_setting    = ($args->{type} || 'entry') . '_max_points';
    my $max            = get_config( $ctx->stash('blog'), $max_setting );
    my $total_width    = star_rater_width(@_)      || 0;
    my $avg_score      = ajax_rating_avg_score(@_) || 0;
    return ($avg_score / $max) * $total_width;
}

sub star_unit_width {
    my ( $ctx, $args ) = @_;
    my $unit_width     = get_config( $ctx->stash('blog'), 'unit_width' );
    $unit_width       *= $args->{mult_by} if $args->{mult_by};
    return $unit_width;
}

sub default_threshold {
    my ( $ctx, $args ) = @_;
    my $threshold      = get_config( $ctx->stash('blog'), 'comment_threshold' );
    return $threshold eq 'all' ? -9999 : $threshold;
}

sub below_threshold {
    my $ctx = shift;
    my ( $mode, $threshold )
        = get_config( $ctx->stash('blog'), 'comment_mode', 'comment_threshold');
    return 0 if $threshold eq 'all' or $mode == 0;

    my $comment     = $ctx->stash('comment');
    my $terms       = { obj_type => 'comment', obj_id => $comment->id };
    my $vsumm = MT->model('ajaxrating_votesummary')->load($terms)
        or return 0;

    my $score = $mode == 1 ? $vsumm->total_score
              : $mode == 2 ? $vsumm->avg_score
                           : 999999999;
    return $score < $threshold ? 1 : 0;
}

sub refresh_hot {  ### TODO Review this
    my ( $ctx, $args ) = @_;
    my $HotObject      = MT->model('ajaxrating_hotobject');
    my $VoteSummary    = MT->model('ajaxrating_votesummary');
    my $start          = time;

    $HotObject->remove_all();

    my $days        = $args->{days} || get_config('system', 'hot_days') || 7;
    my $vs_terms
        = { modified_on => [epoch2ts( undef, $start - 3600 * 24 * $days, 1 ) ]};
    my $vs_args     = { range_incl => { modified_on => 1 } };
    my $vs_iter    = $VoteSummary->load_iter($vs_terms, $vs_args);

    while ( my $vsumm = $vs_iter->() ) {
        my ( $hot_total_score, $hot_vote_count ) = ( 0, 1 );
        my %obj_terms    = map { $_ => $vsumm->$_ } qw( obj_id obj_type );
        $vs_terms        = { %$vs_terms, %obj_terms };
        my $votes_iter   = $vsumm->votes_iter( $vs_args );
        while ( my $vote = $votes_iter->() ) {
            $hot_total_score += $vote->score;
            $hot_vote_count++;
        }

        my $hot = $HotObject->get_by_key( \%obj_terms );
        $hot->set_values({
            vote_count  => $hot_vote_count,
            total_score => $hot_total_score,
            avg_score   => sprintf("%.1f",$hot_total_score / $hot_vote_count),
            ( map { $_ => $vsumm->$_ } qw( blog_id author_id) ),
        });
        $hot->save or warn "Could not save $HotObject: "
                         . ($hot->errstr||'unknown error');;
    }

    my $refresh_time = time - $start;
    MT->log({
       message => "Ajax Ratings Plugin has refreshed the hot objects list ("
                . $refresh_time . " seconds)",
       metadata => $refresh_time,
       class => 'MT::Log::System'
    });
    return '';
}

sub delete_fraud {  ### TODO Review this
    my ( $ctx, $args ) = @_;
    my $start_task     = time;
    my $VoteSummary    = MT->model('ajaxrating_votesummary');
    my $Vote           = MT->model('ajaxrating_vote');
    my $config         = get_config('system');
    return '' unless $config->{enable_delete_fraud};

    my $check_votes = $args->{check_votes} || $config->{check_votes} || 25;
    my $v_args      = { limit => $check_votes, direction => 'descend' };

    # checks objects rated in the past 6 hours # FIXME Uhh, 3 hours?
    my $iter = $VoteSummary->load_iter(
        { modified_on => [ epoch2ts( undef, $start_task - 3600 * 3, 1 ) ] },
        { range_incl  => { modified_on => 1 } }
    );

    my @remove;
    while ( my $summary = $iter->() ) {
        my @recent_votes = $summary->votes( $v_args );
        my $num_votes    = scalar @recent_votes;
        my $start        = 1;
        VOTE: foreach my $vote ( @recent_votes ) {
            foreach my $recent ( grep { $_->is_same($vote) } @recent_votes ) {
                if (    $vote->ip     && $recent->ip
                    and $vote->subnet eq $recent->subnet ) {
                    push( @remove, $vote );
                    last VOTE;
                }
            }
        }
    }

    my $deleted = 0;
    foreach my $vote ( @remove ) {
        if ( $vote->remove ) {
            MT->instance->log(sprintf(
                  'Ajax Ratings has deleted vote %s with duplicate '
                . 'subnet %s on %s %s', $vote->id, $vote->subnet,
                $vote->obj_type, $vote->obj_id
            ));
            $deleted++;
        }
    }
    return unless $deleted;

    my $task_time = time - $start_task;
    MT->instance->log({
       message => "Ajax Ratings Plugin has deleted $deleted votes ("
                . $task_time . " seconds)",
       metadata => $task_time,
       class => 'MT::Log::System'
    });
    return '';
}

sub _migrate_community_votes {

    # Exit immediately unless the user has configured the plugin to perform the
    # migration through the system-level plugin settings;
    return unless get_config(qw( system migrate ));

    my $start_migrate = time;

    my $iter = MT->model('objectscore')->load_iter(
            { namespace => 'community_pack_recommend' });

    my $count = 0;
    while ( my $fav = $iter->() ) {

        # Load or create an ajaxrating_vote object corresponding
        # to the objectscore record in context
        my $vote = MT->model('ajaxrating_vote')->get_by_key({
            voter_id => $fav->author_id,
            obj_type => $fav->object_ds,
            obj_id   => $fav->object_id,
        });

        # Skip if vote exists and has an id because it means the
        # objectscore record has already migrated...
        next if $vote->id;

        # Load the referenced object; skip if not exists
        my $FavClass = MT->model( $fav->object_ds );
        my $obj      = $FavClass->load( $fav->object_id ) || do {
            my $msg = 'Could not locate referenced %s ID %d during '
                    . 'community pack vote migration. Skipping';
            MT->instance->log({
                message => sprintf( $msg, $fav->object_ds, $fav->object_id ),
                level => MT->model('log')->WARNING(),
            });
            undef;
        };
        next unless $obj;

        $vote->set_values({
            ( $obj->can('blog_id') ? ( blog_id => $obj->blog_id ) : () ),
            ( map { $_ => $fav->$_ }
                qw( score ip created_on created_by modified_by modified_on) )
        });
        $vote->save
            or die sprintf(
                'Could not save %s ID %d on %s ID %d: %s',
                blessed($vote), $vote->id, $vote->obj_type,
                $vote->obj_id, ($vote->errstr||'unknown error')
            );
        $count++;
    }

    my $plugin = MT->component('ajaxrating');
    $plugin->set_config_value('migrate', 0, 'system');

    my $migrate_time = time - $start_migrate;

    MT->instance->log({
       message => "Ajax Ratings Plugin has migrated " . $count
                . " Community Pack votes (" . $migrate_time . " seconds)",
       metadata => $migrate_time,
       class => 'MT::Log::System'
    });

    return '';
}

sub session_state {
    my ( $cb, $app, $c, $commenter ) = @_;
    my $q       = $app->param if $app->can('param');
    my $blog_id = $q->param('blog_id') if $q;
    my @votes   = MT->model('ajaxrating_vote')->load({
                    voter_id => $commenter->id,
                    obj_type => 'entry',
        ($blog_id ? (blog_id => $blog_id) : ()),
    });

    $c->{user_votes} = { map { $_->obj_id => $_->score } @votes }
        if @votes;

    return ( $c, $commenter );
}

sub rebuild_ar_templates {
    my ( $app )   = @_;
    my $Template  = MT->model('template');
    my $blog_id   = $app->param('blog_id') or die "No blog in context";
    my %rebuild   = ( BlogID  => $blog_id, Force => 1 );

    my $load_tmpl = sub {
        my $tmpl  = shift or return;
        $Template->load({
            blog_id => $blog_id, map { $_ => $tmpl->{$_} } qw( name type )
        });
    };

    foreach ( grep { $_->{type} eq 'index'} @{template_info()} ) {
        my $tmpl = $load_tmpl->($_) or next;
        next if $app->rebuild_indexes( %rebuild, Template => $tmpl );
        $app->log( $app->errstr || 'Unknown error in rebuild_ar_templates' );
    }
}

# When upgrading to schema_version 3, vote distribution data needs to be
# calculated.
sub upgrade_add_vote_distribution { shift()->compile_vote_dist() }

# schema_version 4 reflects the move to the config.yaml style plugin. Plugin
# data was previously saved with the name "AJAX Rating Pro" which isn't easily
# accessible, so update it to use "ajaxrating."
sub upgrade_migrate_plugin_data {
    my ( $pdata ) = @_;
    if ( $pdata->plugin eq 'AJAX Rating Pro' ) {
        $pdata->plugin('ajaxrating');
        $pdata->save or die $pdata->errstr;
    }
}

sub context_author {
    my ( $ctx, $args )      = @_;
    my ( $Author, $author ) = ( MT->model('author'), undef );
    my $id_arg              = first_value { $args->{$_} }
                                            qw( author_id voter_id user_id );
    if ( $id_arg ) {
        $author = $Author->load( $args->{$id_arg} )
            or return $ctx->error(sprintf(
                'Invalid %s argument in %s: Author %d not found',
                    $id_arg, $ctx->this_tag, $args->{$id_arg} ));
    }
    else {
        $author = $ctx->stash('author');
    }

    return blessed($author) && $author->isa($Author)
        ? $author : $ctx->error('No author context for '.$ctx->this_tag);
}

sub object_from_args {
    my ( $ctx, $args ) = @_;
    my %h = ( obj_type => $args->{type} || '',
              obj_id   => $args->{id}   || 0  );
    $h{obj_type} = $h{obj_type} eq 'trackback' ? 'ping'
                 : $h{obj_type}                ? $h{obj_type}
                 : $ctx->stash('comment')      ? 'comment'
                                               : 'entry';
    unless ( $h{obj_id} ) {
        $h{obj} = $ctx->stash( $h{obj_type} )
            or return $ctx->error(sprintf(
                "No %s in context or specified with 'id' attribute to %s tag",
                $h{obj_type}, $ctx->this_tag
            ));
        $h{obj_id} = $h{obj}->id;
    }
    return %h;
}

sub template_info {
    return [
        {
            outfile    => 'ajaxrating.js',
            name       => 'Ajax Rating Javascript',
            type       => 'index',
            rebuild_me => '0'
        },
        {
            outfile    => 'ajaxrating.css',
            name       => 'Ajax Rating Styles',
            type       => 'index',
            rebuild_me => '0'
        },
        {
            name       => 'Widget: Ajax Rating',
            type       => 'custom',
            rebuild_me => '0'
        },
    ];
}

sub install_templates {
    my ( $plugin, $app ) = @_;
    my $blog_id          = $app->param('blog_id') or die "No blog in context";
    my $Template         = MT->model('template');
    my $templates        = template_info();
    my $path             = 'plugins/AjaxRating/templates';

    my $perms = $app->{perms};  ### FIXME This is wrong
    return $app->error(
            'You do not have permissions to modify templates in this blog.')
        unless $perms->can_edit_templates()
            || $perms->can_administer_blog
            || $app->user->is_superuser();


    require MT::Util;
    require File::Spec;
    my $load_template_text = sub {
        my $name = MT::Util::dirify(+shift);
        ### TODO Use Path::Tiny/File::Slurp
        my $file = File::Spec->catfile( $path,"$name.tmpl" );
        return '' unless -e $file and -r $file;
        my $text = do {
            local (*FIN, $/); $/ = undef;
            open FIN, "<$file"; my $data = <FIN>; close FIN;
            $app->translate_templatized( $data )
        }
    };

    my ( @existing, @unsaved );
    foreach my $meta (@$templates) {
        $meta = { %$meta,
            name          => $app->translate( $meta->{name} ),
            blog_id       => $blog_id,
            build_dynamic => 0,
            text          => $load_template_text->( $meta->{name} )
        };

        my $tmpl = MT->model('template')->get_by_key({
            map { $_ => $meta->{$_} } qw( blog_id type name )
        });
        $tmpl->set_values( $meta );
        push(( $tmpl->id ? @existing : @unsaved ), $tmpl );
    }

    if ( @existing ) {
        return $app->error(
              'Some templates already exist. To reinstall the default '
            . 'templates, first delete or rename the existing templates: '
            . join(', ', map { $_->name } @existing )
        );
    }

    foreach my $tmpl ( @unsaved ) {
        $tmpl->save or return $app->error("Error creating new template: "
                                         . $tmpl->errstr);
        $app->rebuild_indexes(
            BlogID => $blog_id, Template => $tmpl, Force => 1 );
    }

    $app->redirect($app->uri( mode => 'cfg_plugins',
                              args => { 'blog_id' => $blog_id } ) );
}

sub blog_config_template {
    my ( $plugin, $param ) = @_;
    my $app                = MT->instance;

    rebuild_ar_templates($app);

    $param->{blog_id}   = $app->param('blog_id');
    $param->{installer} = try { MT->component('TemplateInstaller') ? 1 : 0 };
        # ^^^ If the Template Installer plugin is installed,
        # shows the "Install Templates" link.

    return $plugin->load_tmpl( 'blog_config_template.tmpl', $param );
}

sub rater {
    my ( $ctx, $args ) = @_;
    my $blog      = $ctx->stash('blog');
    my %obj_info  = object_from_args(@_) or return;
    my $obj_type  = $obj_info{obj_type};
    my $author_id = $obj_type eq 'comment' ? $obj_info{obj}->commenter_id
                  : $obj_type eq 'entry'   ? $obj_info{obj}->author_id
                                           : 0;
    my $vsumm = MT->model('ajaxrating_votesummary')->get_by_key({
        obj_type => $obj_type,
        obj_id   => $obj_info{obj_id},
    });

    my $param = {
        rater_type  => $args->{rater_type} || 'star',
        author_id   => $author_id          || 0,
        map { $_ => $vsumm->$_ || 0 } @{$vsumm->column_names}
    };

    if ( $param->{rater_type} eq 'star' ) {
        my $config       = get_config( $blog->id );
        my $unit_width   = $config->{unit_width};
        my $units        = $config->{$obj_type . '_max_points'}
                        || $args->{max_points}
                        || 5;
        my $rater_length = ( $units * $unit_width );

        $param = { %$param,
            ratingl      => $config->{ratingl},
            unit_width   => $unit_width,
            units        => $units,
            rater_length => "${rater_length}px",
            star_loop    => [ 1..$units ],
            star_width   => sprintf( '%.1fpx',
                                $param->{avg_score} / $units * $rater_length ),
        };
    }
    elsif ( $param->{rater_type} eq 'onclick_js' ) {
        $param->{points} = defined ($args->{points}) ? $args->{points} : 1;
    }
    else {
        $param->{report_icon} = $args->{report_icon};
        $param->{static_path}
            = MT->instance->static_path . "plugins/AjaxRating/images";
    }
    my $plugin = MT->component('ajaxrating');
    my $tmpl = $plugin->load_tmpl( 'rater.tmpl' );
    local $tmpl->{context} = $ctx;     # propagate our context
    defined( my $out = $tmpl->output($param) )
        or return $ctx->error( $tmpl->errstr );
    $out =~ s{(\A\s+|\s+\Z)}{}g;
    return $out;
}


1;

__END__
