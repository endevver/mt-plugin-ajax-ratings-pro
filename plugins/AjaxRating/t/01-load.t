#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;

package Test::AjaxRating::Util::Load {
    ::use_ok( 'AjaxRating::Util' );
}
package Test::AjaxRating::Object::Load {
    ::use_ok( 'AjaxRating::Object' );
}
package Test::AjaxRating::Object::HotObject::Load {
    ::use_ok( 'AjaxRating::Object::HotObject' );
}
package Test::AjaxRating::Object::Vote::Load {
    ::use_ok( 'AjaxRating::Object::Vote' );
}
package Test::AjaxRating::Object::VoteSummary::Load {
    ::use_ok( 'AjaxRating::Object::VoteSummary' );
}
package Test::AjaxRating::App::Load {
    ::use_ok( 'AjaxRating::App' );
}
package Test::AjaxRating::CMS::Load {
    ::use_ok( 'AjaxRating::CMS' );
}
package Test::AjaxRating::App::AddVote::Load {
    ::use_ok( 'AjaxRating::App::AddVote' );
}
package Test::AjaxRating::App::GetVotes::Load {
    ::use_ok( 'AjaxRating::App::GetVotes' );
}
package Test::AjaxRating::App::ReportComment::Load {
    ::use_ok( 'AjaxRating::App::ReportComment' );
}
package Test::AjaxRating::DataAPI::Endpoint::Common::Load {
    ::use_ok( 'AjaxRating::DataAPI::Endpoint::Common' );
}
package Test::AjaxRating::DataAPI::Callback::Init::Load {
    ::use_ok( 'AjaxRating::DataAPI::Callback::Init' );
}
package Test::AjaxRating::DataAPI::Callback::Vote::Load {
    ::use_ok( 'AjaxRating::DataAPI::Callback::Vote' );
}
package Test::AjaxRating::DataAPI::Endpoint::Vote::Load {
    ::use_ok( 'AjaxRating::DataAPI::Endpoint::Vote' );
}
package Test::AjaxRating::DataAPI::Endpoint::VoteSummary::Load {
    ::use_ok( 'AjaxRating::DataAPI::Endpoint::VoteSummary' );
}
package Test::AjaxRating::DataAPI::Resource::Foreign::Load {
    ::use_ok( 'AjaxRating::DataAPI::Resource::Foreign' );
}
package Test::AjaxRating::DataAPI::Resource::HotObject::Load {
    ::use_ok( 'AjaxRating::DataAPI::Resource::HotObject' );
}
package Test::AjaxRating::DataAPI::Resource::Vote::Load {
    ::use_ok( 'AjaxRating::DataAPI::Resource::Vote' );
}
package Test::AjaxRating::DataAPI::Resource::VoteSummary::Load {
    ::use_ok( 'AjaxRating::DataAPI::Resource::VoteSummary' );
}
package Test::AjaxRating::Upgrade::AbbrevTables::Load {
    ::use_ok( 'AjaxRating::Upgrade::AbbrevTables' );
}
package Test::AjaxRating::Upgrade::PLtoYAML::Load {
    ::use_ok( 'AjaxRating::Upgrade::PLtoYAML' );
}
package Test::AjaxRating::Load {
    ::use_ok( 'AjaxRating' );
}
package Test::MT::Object::LegacyFactory::Load {
    ::use_ok( 'MT::Object::LegacyFactory' );
}
package Test::SocialStats::Entry::AjaxRating::Load {
    ::use_ok( 'SocialStats::Entry::AjaxRating' );
}

done_testing();

__END__
