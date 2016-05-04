# EntryPost http://mt-hacks.com

package AjaxRating::App::ReportComment;

use strict;
use warnings;
use 5.0101;  # Perl v5.10.1 minimum
use Sub::Install;

use AjaxRating::App;
@AjaxRating::App::ReportComment::ISA = qw( AjaxRating::App );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        report  => \&default_mode,  # alias for backcompat
    );
    $app;
}

sub default_mode {
    my $app = shift;
    my $q = $app->{query};
    return "ERR||Invalid request, must use POST."
        if $app->request_method() ne 'POST';
    require MT::Mail;
    my($author, $subj, $body);
    my $cfg = MT::ConfigMgr->instance;
    use MT::Comment;
    my $comment = MT::Comment->load($q->param('id'))
        or return;
    my $entry = $comment->entry;
    $author = $entry->author;
    my $blog = $entry->blog;
    my $path = $cfg->CGIPath;
    if ($path =~ m!^/!) {
        # relative path, prepend blog domain
        my ($blog_domain) = $blog->archive_url =~ m|(.+://[^/]+)|;
        $path = $blog_domain . $path;
    }
    $path .= '/' unless $path =~ m!/$!;
    my $editpath = $path . $cfg->AdminScript . "?__mode=view&_type=comment&id=" . $q->param('id') . "&blog_id=" . $entry->blog_id;
    $app->set_language($author->preferred_language)
        if $author && $author->preferred_language;
    $subj = $app->translate('AjaxRating: Comment Reported');
    $body = $app->translate('The following comment has been reported by ' . $app->remote_ip . ':');
    if ($author && $author->email) {
           my %head = ( To => $author->email,
                         From => $author->email,
                         Subject => '[' . $blog->name . '] ' . $subj );
            my $charset = $cfg->PublishCharset || 'iso-8859-1';
            $head{'Content-Type'} = qq(text/plain; charset="$charset");
            require Text::Wrap;
            $Text::Wrap::cols = 72;
            $body = Text::Wrap::wrap('', '', $body) . "\n\n" .
                 $app->translate('Name:') . ' ' . $comment->author . "\n\n" .
                 $app->translate('Email:') . "\n" . $comment->email . "\n\n" .
                 $app->translate('URL:') . ' ' . $comment->url . "\n\n" .
                 $app->translate('Comments:') . "\n" . $comment->text . "\n\n" .
                 $app->translate('Edit:') . "\n" . $editpath . "\n\n";
            MT::Mail->send(\%head, $body);
    }
    return "ERR||This comment has been reported."
}

BEGIN {
    Sub::Install::install_sub({     # Backwards compat
        code => 'default_mode',
        as   => 'report'
    });
}

1;
