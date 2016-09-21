#!/usr/local/bin/perl -w

use strict;
use lib "lib", ($ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : "../../lib");
use 5.0101;  # Perl v5.10.1 minimum
use MT::Bootstrap App => 'AjaxRating::App::GetVotes';
