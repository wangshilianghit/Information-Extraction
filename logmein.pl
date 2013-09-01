#!/usr/bin/env perl
use strict;
use warnings;
use WWW::Mechanize;   #library need to be installed using cpan, $ cpan, $ force install WWW::Mechanize
use LWP::UserAgent;
use HTML::Parser;
use HTML::TreeBuilder;
use URI::URL;
use HTTP::Request::Common qw(POST);
use HTTP::Request::Common qw(GET);
use HTTP::Cookies;
use LWP::Simple;
use HTML::FormatText;
use open ':std', ':encoding(UTF-8)';

my $ua = LWP::UserAgent->new;

# Define user agent type
$ua->agent('Mozilla/8.0');

# Request object
# my $req_url = GET 'http://www.nature.com.proxy1.library.jhu.edu/scientificamerican/archive/index.html';
# my $content = check_response($req_url);
# print $content;

my $username = 'swang129'; 
my $password = 'Study@littlebird13';
my $mech = WWW::Mechanize->new();
my $outfile = "output.html";
$mech -> cookie_jar(HTTP::Cookies->new());
$mech -> get('http://www.nature.com.proxy1.library.jhu.edu/scientificamerican/archive/index.html');
$mech -> form_name('EZproxyForm');
$mech -> click ();
$mech -> form_name('loginform');
$mech -> field ('USER' => $username);
$mech -> field ('PASSWORD' => $password);
$mech -> click ('submit1');
$mech -> click ();  #comment either this or above line out for unsupported javascript error...
my $content =  $mech-> content();
open(OUTFILE, ">$outfile");
print OUTFILE "$content";
close(OUTFILE);

sub check_response{
	my $req = shift;

	# Make the request
	my $res = $ua->request($req);
	my $content = undef;
	# Check the response
	if ($res->is_success) {
	    $content = $res->content;
	} else {
	    print $res->status_line . "\n";
	}

	return $content;
}
