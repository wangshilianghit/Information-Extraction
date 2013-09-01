#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use WWW::Mechanize;   #library need to be installed using cpan, $ cpan, $ force install WWW::Mechanize
use File::Path;
use strict;
use LWP::Simple;
use HTML::Parser;
use HTML::TreeBuilder;
use URI::URL;
use HTTP::Request;
use HTTP::Response;
use HTTP::Cookies;
use HTML::FormatText;
use Term::ReadKey;
use open ':std', ':encoding(UTF-8)';

my $ua = LWP::UserAgent->new;

# Define user agent type
$ua->agent('Mozilla/8.0');

# Request object
# my $req_url = GET 'http://www.nature.com.proxy1.library.jhu.edu/scientificamerican/archive/index.html';
# my $content = check_response($req_url);
# print $content;
if ( scalar @ARGV != 1) {
    print "The program should be invoked as follows: Invocation = ./sa_extract.pl path\n";  
    exit
}
my $username = undef;
my $password = undef;
my $mech = WWW::Mechanize->new();
my $outfile = "output.html";
my $base_url = 'http://www.nature.com.proxy1.library.jhu.edu';
my $base_directory = shift(@ARGV);
my $directory = '';

if (not -d $base_directory){
    print "Doesn't exist the directory: " . $base_directory . "\n";
    exit;
}

my $last_char = substr($base_directory, length($base_directory) - 1, 1);
if ($last_char ne "/") {
    $base_directory = $base_directory . "/";
}

print "Please input your JHU ID:" . "\n";
$username = <STDIN>;
chomp ($username);

print "Please input your JHU Password:" . "\n";
ReadMode('noecho');
$password = <STDIN>;
chomp ($password);
ReadMode(0);

print "Connecting to the server now..." . "\n";
$mech -> cookie_jar(HTTP::Cookies->new());
$mech -> get('http://www.nature.com.proxy1.library.jhu.edu/scientificamerican/archive/index.html');
$mech -> form_name('EZproxyForm');
$mech -> click ();
$mech -> form_name('loginform');
$mech -> field ('USER' => $username);
$mech -> field ('PASSWORD' => $password);
$mech -> click ('submit1');
$mech -> click ();  
my $content =  $mech-> content();
my $pdf_number = 0;
open(OUTFILE, ">$outfile");
print OUTFILE "$content";
close(OUTFILE);

print "Downloading the pdf files now..." . "\n";
&grab_urls($content, $base_url); 
print "Download completed." . "\n";
print "Total ariticles downloaded: " . $pdf_number . "\n";

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

sub grab_urls {
    my $content = shift;
    my $base_url = shift;

    my $year_regex = qr/(?ms)class="volume">([0-9]{4}).{1,5000}?<span class="cleardiv"><!-- --><\/span>/;
    my $link_regex = qr/(?ms)<h4 class="month">([A-Za-z]{1,20}).{1,50}<a href="(.{1,100})"><span class=/;
    while ($content =~m/$year_regex/gm){
        my $year = $1;
        if ($year eq "2013"){
            next;
        }
        print "Starting downloding the articles of year " . $year . "\n";
        $directory = $base_directory . $year . "/";
        my $sub_content = $&;
        mkpath($directory);
        while ($sub_content =~ m/$link_regex/gm) {
            my $month = $1;
            my $link = $2;
            my $url = $base_url . $link; 
            $directory = $base_directory . $year . "/" . $month . "/";
            mkpath($directory);
            $mech -> get($url);
            my $new_content = $mech-> content();
            &grab_pdfs($new_content, $base_url);
        } 
    }
} 

sub grab_pdfs {
    my $content = shift;
    my $base_url = shift;
    
    my $regex = qr/(?ms)<span class="hidden"> - (.{1,50})<\/span>.{1,100}href="(.{1,100}.pdf)/;
   
    while ($content =~m/$regex/gm){
        my $title = $1;
        my $pdf_link = $2;
        my $url = $base_url . $pdf_link;
        #print "Title: " . $title . ".pdf\n";
        #print "Url: " . $url . "\n";
        my $current_directory = $directory . $title . ".pdf";
        if (not -e $current_directory) {
            $mech->get($url, ":content_file" => $current_directory);
            ++$pdf_number;
        }
    }
}

