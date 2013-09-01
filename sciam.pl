#!/usr/bin/perl
use strict;
use warnings;
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
my $mag_issue = "2012-09";  #"2013-03";
my $base_url = "scientificamerican.com";
# print $url . "\n";
my $req = POST 'http://www.scientificamerican.com/sciammag/', [ contents=>$mag_issue];

# Make the request
my $res = $ua->request($req);
my $content = undef;
# Check the response
if ($res->is_success) {
    $content = $res->content;
    #print $content;
} else {
    print $res->status_line . "\n";
}
# print $content;

my $num = 0;
#TODO does not grab multiple article authors, only first author retrieved
#TODO make subfunctions
#initial landing page for a specific month issue
my $issue_regex = qr/(?ms)<h3>.+?href="([^"]*).+?title="Feature">([^<]*).+?class="byline">.+?author.+?>([^<]*)/;  #rather stiff way of code

while ($content =~ m/$issue_regex/gm){
    ++$num;
    my $article_link = undef;
    $article_link = $1;
    my $title = $2;
    my $author = $3;

    # print $article_link,"\n";
    my $article_page = GET $article_link;
    my $page_content = $ua->request($article_page);
    my $desc_content = undef;

    if ($page_content->is_success) {
        $desc_content = $page_content->content;
    } else {
        print $page_content->status_line . "\n";
    }
    # print $desc_content;

    #article content extractor
    my $article_regex = qr/(?ms)id="articleContent">(.+?)id="articleBottom/;
    
    #article pagination extractor
    my $pages_regex = qr/(?ms)id="articlePagination">(.+?)<\/div>/;
    my $pages = undef;
    ($pages) = $desc_content =~ m/$pages_regex/gm;
    my @pages = ();
    
    if ( defined $pages ){
        # print "my pages: " . $pages . "\n";
        my $pagination_regex = qr/(?ms)href="([^"]*)/;
        while ( $pages =~ m/$pagination_regex/gm ){
            push @pages, $1;
        }
    }

    pop @pages;  #removes the link for the "next" button

    my ($article_content_raw) = $desc_content =~ m/$article_regex/gm;  #obtain first page's raw html contents
    # TODO fix the preview article check
    # my $preview = undef;
    # ($preview) = $desc_content =~ m/class\=\"articleTitle\"\>([^h1]*)/sm;

    foreach my $cur_page_url (@pages){
        $cur_page_url =~ s/\&amp\;/\&/;   #TODO need better way of doing this
        $cur_page_url = (new URI::URL $cur_page_url)->abs( $page_content->base );  #obtain absolute url
        # print "my absolute page url: " . $cur_page_url . "\n";

        my $cur_page = GET $cur_page_url;
        my $other_page_content = $ua->request($cur_page);
        my $other_desc_content = undef;

        if ($other_page_content->is_success) {
            $other_desc_content = $other_page_content->content;
        } else {
            print $other_page_content->status_line . "\n";
        }
        $article_content_raw .= extract_content($other_desc_content,$article_regex);
    }

    #extraction of article images
    my $html_tree = new HTML::TreeBuilder;
    $html_tree->parse($article_content_raw);
    foreach my $item (@{$html_tree->extract_links( "img" )}) {
        my $link = shift @$item;
        my $furl = (new URI::URL $link)->abs( $page_content->base );  #make sure to get the url that includes the base url
        if ($furl =~ /$base_url/){  #toss out junk images
            # print "image file url: " . $furl, "\n";
            my $filename = undef;
            $filename = $furl->path();
            $filename =~ s/.+?imported\///g;  #create image filename based on url
            $filename = "./images/" . $filename;
            # print "file name: " . $filename,"\n";
            getstore($furl, $filename);  #saves article images
        }
    }

    print "title: " . $title . "\n";
    print "article link: " . $article_link . "\n";
    # print "preview: " . $preview . "\n";
    print "author: " . $author ."\n";
    
    my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
    my $article_content_formatted = $formatter->format($html_tree);

    print "article formatted: " . $article_content_formatted . "\n";
    print "\n";
    $html_tree->delete( );
}

print "total number: " . $num . "\n";

sub extract_content {
    my $html = shift;
    my $regex = shift;

    my $content = undef;
    ($content) = $html =~ m/$regex/gm;
    return $content;    
}

exit 0;
