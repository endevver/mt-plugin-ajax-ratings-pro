#!/usr/local/bin/perl

use Test::AjaxRating::Tools;
use Test::MT::Suite;
use DDP;

use MT::Builder;
sub tmpl_out_is;
sub tmpl_out_like;

my $suite  = Test::MT::Suite->new();
my $app    = MT->instance;
my ($Blog, $Entry, $VS) = map { $app->model($_) }
                            qw( blog entry ajaxrating_votesummary);
my $vsiter = $VS->load_iter({ obj_type => 'entry' },
                            { sort => 'id', direction => 'descend' });

my ( $cnt, $blog, $blog_id, $entry, $entry_id, $vsumm, %blog_votes );

do {
    $vsumm = $vsiter->()                  or last;
    $entry = $Entry->load($vsumm->obj_id) or next;
    subtest 'Entry ID'.$entry->id => \&check_templates;
    $cnt++
} until ( $cnt == 10 );


sub check_templates {
    isa_ok( $vsumm,                 $VS,    'VoteSummary' );
    isa_ok( $entry,                 $Entry, 'Entry' );
    isa_ok( $blog  = $entry->blog,  $Blog,  'Blog' );
    $blog_id  = $blog->id;
    $entry_id = $entry->id;
    my ( $count, $total, $avg )
        = map { $vsumm->$_ } qw( vote_count total_score avg_score );
    tmpl_out_is '<mt:BlogId>',                          $blog_id;
    tmpl_out_is '<mt:EntryId>',                         $entry->id;
    tmpl_out_is '<mt:AjaxRating>',                      $total;
    tmpl_out_is '<mt:AjaxRating show="total_score">',   $total;
    tmpl_out_is '<mt:AjaxRating show="avg_score">',     $avg;
    tmpl_out_is '<mt:AjaxRating show="vote_count">',    $count;
    tmpl_out_is '<mt:AjaxRatingAverageScore>',          $avg;
    tmpl_out_is '<mt:AjaxRatingAvgScore>',              $avg;
    tmpl_out_is '<mt:AjaxRatingTotalScore>',            $total;
    tmpl_out_is '<mt:AjaxRatingVoteCount>',             $count;

    $blog_votes{$blog_id} ||= $app->model('ajaxrating_vote')->count({
        blog_id => $blog_id, obj_type => 'entry'
    });
    tmpl_out_is '<mt:AjaxRatingTotalVotesInBlog>',      $blog_votes{$blog_id};

    ### TODO Test AjaxRater args: type, id, max_points and report_icon
    tmpl_out_like '<mt:AjaxRater>',                         star_rater();
    tmpl_out_like '<mt:AjaxStarRater>',                     star_rater();
    tmpl_out_like '<mt:AjaxRater rater_type="thumb">',      thumb_rater();
    tmpl_out_like '<mt:AjaxThumbRater>',                    thumb_rater();
    tmpl_out_like '<mt:AjaxRater rater_type="onclick_js">', js_rater();
    tmpl_out_like '<mt:AjaxRaterOnclickJS>',                js_rater();
    tmpl_out_like '<mt:AjaxRater rater_type="onclick_js" points="5">',
        js_rater(5);
    tmpl_out_like '<mt:AjaxRaterOnclickJS points="5">',
        js_rater(5);

    ### TODO Test Remaining tags
    # tmpl_ok '<mt:AjaxRatingEntryMax>',
    # tmpl_ok '<mt:AjaxRatingCommentMax>',
    # tmpl_ok '<mt:AjaxStarRaterWidth>',
    # tmpl_ok '<mt:AjaxStarRaterAverageScoreWidth>',
    # tmpl_ok '<mt:AjaxStarUnitWidth>',
    # tmpl_ok '<mt:AjaxRatingDefaultThreshold>',
    # tmpl_ok '<mt:AjaxRatingRefreshHot>',
    # tmpl_ok '<mt:AjaxRatingUserVoteCount>',
    # tmpl_ok '<mt:IfAjaxRatingBelowThreshold> BLAH </mt:IfAjaxRatingBelowThreshold>',
    # tmpl_ok '<mt:AjaxRatingList> BLAH </mt:AjaxRatingList>',
    # tmpl_ok '<mt:AjaxRatingEntries> BLAH </mt:AjaxRatingEntries>',
    # tmpl_ok '<mt:AjaxRatingComments> BLAH </mt:AjaxRatingComments>',
    # tmpl_ok '<mt:AjaxRatingPings> BLAH </mt:AjaxRatingPings>',
    # tmpl_ok '<mt:AjaxRatingBlogs> BLAH </mt:AjaxRatingBlogs>',
    # tmpl_ok '<mt:AjaxRatingCategories> BLAH </mt:AjaxRatingCategories>',
    # tmpl_ok '<mt:AjaxRatingTags> BLAH </mt:AjaxRatingTags>',
    # tmpl_ok '<mt:AjaxRatingAuthors> BLAH </mt:AjaxRatingAuthors>',
    # tmpl_ok '<mt:AjaxRatingUserVotes> BLAH </mt:AjaxRatingUserVotes>',
    # tmpl_ok '<mt:AjaxRatingVoteDistribution> BLAH </mt:AjaxRatingVoteDistribution>',
}

done_testing();

sub star_rater {
    my ( $count, $total, $avg, $author ) = map { $vsumm->$_ || 0 }
                        qw( vote_count total_score avg_score author_id );
    qr/width:\d+.\d+px .*
       r1-unit\srater   .*
       pushRating\('entry',$entry_id,1,$blog_id,$total,$count,$author\);/smx;
}

sub thumb_rater {
    my ( $count, $total, $avg, $author ) = map { $vsumm->$_ || 0 }
                        qw( vote_count total_score avg_score author_id );
    qr/Vote\sup.*
       onclick.*
       pushRating\('entry',$entry_id,1,$blog_id,$total,$count,$author\)/smx;
}

sub js_rater {
    my $points = shift || 1;
    my ( $count, $total, $avg, $author ) = map { $vsumm->$_ || 0 }
                        qw( vote_count total_score avg_score author_id );
    qr/pushRating\('entry',
       $entry_id,$points,$blog_id,$total,$count,$author\);\s+
       return\(false\);/smx;
}

sub tmpl_out_is($$;$) {
    my ( $text, $expected, $name ) = @_;
    my $param;
    my $ctx_h = context();
    is( MT::Test::_tmpl_out( $text, $param, $ctx_h ), $expected, $name || $text );
}

sub tmpl_out_like($$;$) {
    my ( $text, $re, $name ) = @_;
    my $param;
    my $ctx_h = context();
    MT::Test::tmpl_out_like( $text, $param, $ctx_h, $re, $name || $text );
}

sub tmpl_builds_ok($;$) {
    my ( $text, $name ) = @_;
    my $tmpl    = $app->model('template')->new;
    $tmpl->text( $text );

    my $ctx     = $tmpl->context;
    my $context = context();
    $ctx->stash( $_, $context->{$_} ) for keys %$context;

    my $build = $tmpl->build;
    is( $ctx->errstr, undef, 'builds_ok: '.($name || $text) );
}

sub context {
    my $ctx = { 'builder' => MT::Builder->new };
    if ( $blog ) {
        $ctx->{blog}          = $blog;
        $ctx->{blog_id}       = $blog->id;
        $ctx->{local_blog_id} = $blog->id;
    }

    if ( $entry ) {
        $ctx->{entry}         = $entry;
        $ctx->{entry_id}      = $entry->id;
    }
    $ctx;
}

__END__

