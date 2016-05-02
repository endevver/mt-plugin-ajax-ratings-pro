#!/usr/local/bin/perl

use Test::More;

package Test::AjaxRating::Object::Load {
    ::use_ok('AjaxRating::Object');
}

package Test::AjaxRating::Util::Load {
    ::use_ok('AjaxRating::Util');
}

package Test::AjaxRating::App::Load {
    ::use_ok('AjaxRating::App');
}

package Test::AjaxRating::CMS::Load {
    ::use_ok('AjaxRating::CMS');
}

package Test::AjaxRating::DataAPI::Load {
    ::use_ok('AjaxRating::DataAPI');
}

package Test::AjaxRating::App::AddVote::Load {
    ::use_ok('AjaxRating::App::AddVote');
}

package Test::AjaxRating::App::GetVotes::Load {
    ::use_ok('AjaxRating::App::GetVotes');
}

package Test::AjaxRating::App::ReportComment::Load {
    ::use_ok('AjaxRating::App::ReportComment');
}

package Test::AjaxRating::DataAPI::Resources::Load {
    ::use_ok('AjaxRating::DataAPI::Resources');
}

package Test::AjaxRating::Object::HotObject::Load {
    ::use_ok('AjaxRating::Object::HotObject');
}

package Test::AjaxRating::Object::Vote::Load {
    ::use_ok('AjaxRating::Object::Vote');
}

package Test::AjaxRating::Object::VoteSummary::Load {
    ::use_ok('AjaxRating::Object::VoteSummary');
}

package Test::AjaxRating::Upgrade::AbbrevTables::Load {
    ::use_ok('AjaxRating::Upgrade::AbbrevTables');
}

package Test::AjaxRating::Upgrade::PLtoYAML::Load {
    ::use_ok('AjaxRating::Upgrade::PLtoYAML');
}

package Test::MT::Object::LegacyFactory::Load {
    ::use_ok('MT::Object::LegacyFactory');
}

package Test::SocialStats::Entry::AjaxRating::Load {
    ::use_ok('SocialStats::Entry::AjaxRating');
}

package Test::AjaxRating::Load {
    ::use_ok('AjaxRating');
}

done_testing();

__END__
