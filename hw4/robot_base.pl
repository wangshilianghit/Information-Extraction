#!/usr/bin/env perl
#Shiliang Wang,  Guannan Ren
#Email: wangshiliang@jhu.edu    gren3@jhu.edu
#Assignment 4: Web Robots
#
# This program walks through HTML pages, extracting all the links to other
# text/html pages and then walking those links. Basically the robot performs
# a breadth first search through an HTML directory structure.
#
# All other functionality must be implemented
#
# Example:
#
#    robot_base.pl mylogfile.log content.txt http://www.cs.jhu.edu/
#
# Note: you must use a command line argument of http://some.web.address
#       or else the program will fail with error code 404 (document not
#       found).

no warnings 'uninitialized';
use strict;

use Carp;
use FileHandle;
use HTML::Element;
use HTML::LinkExtor;
use HTTP::Request;
use HTTP::Response;
use HTTP::Status;
use LWP::RobotUA;
use LWP::UserAgent;
use URI::URL;
use HTML::TokeParser;
use HTML::HeadParser;
use HTML::TreeBuilder;

URI::URL::strict( 1 );   # insure that we only traverse well formed URL's

$| = 1;

my %token_vector = ();

my $log_file = shift (@ARGV);
my $content_file = shift (@ARGV);
my $link_file = "link.txt";
if ((!defined ($log_file)) || (!defined ($content_file))) {
    print STDERR "You must specify a log file, a content file and a base_url\n";
    print STDERR "when running the web robot:\n";
    print STDERR "  ./robot_base.pl mylogfile.log content.txt base_url\n";
    exit (1);
}

open LOG, ">$log_file";
open CONTENT, ">$content_file";
open LINK, ">$link_file";
 
my $ROBOT_NAME = 'crawler/1.0';
my $ROBOT_MAIL = 'wangshiliang@jhu.edu';

# create an instance of LWP::RobotUA. 
#
# Note: you _must_ include a name and email address during construction 
#       (web site administrators often times want to know who to bitch at 
#       for intrusive bugs).
#
# Note: the LWP::RobotUA delays a set amount of time before contacting a
#       server again. The robot will first contact the base server (www.
#       servername.tag) to retrieve the robots.txt file which tells the
#       robot where it can and can't go. It will then delay. The default 
#       delay is 1 minute (which is what I am using). You can change this 
#       with a call of
#
#         $robot->delay( $ROBOT_DELAY_IN_MINUTES );
#
#       At any rate, if your program seems to be doing nothing, wait for
#       at least 60 seconds (default delay) before concluding that some-
#       thing is wrong.
#

my $robot = new LWP::RobotUA $ROBOT_NAME, $ROBOT_MAIL;
$robot->delay( $0.4 );

my $root_url    = shift(@ARGV);   # the root URL we will start from

my @search_urls = ();    # current URL's waiting to be trapsed
my @wanted_urls = ();    # URL's which contain info that we are looking for
my %relevance   = ();    # how relevant is a particular URL to our search
my %pushed      = ();    # URL's which have either been visited or are already
                         #  on the @search_urls array
                         
my $stoplist   = "common_words";   # common uninteresting words
my %stoplist_hash  = ( );

my $stoplist_fh   = new FileHandle $stoplist  , "r"
    or croak "Failed $stoplist";

while (defined( my $line = <$stoplist_fh> )) {
    chomp $line;
    $stoplist_hash{ $line } = 1;
}
                     
my $url = URI->new( $root_url );
my $domain = $url->host;
my $extract_number = 0;
#print "domain: " . $domain . "\n\n";
    
push @search_urls, $root_url;

while (@search_urls) {
    my $url = shift @search_urls;
    #print "next url: " . $url . "\n";

    #
    # insure that the URL is well-formed, otherwise skip it
    # if not or something other than HTTP
    #

    my $parsed_url = eval { new URI::URL $url; };

    next if $@;
    next if $parsed_url->scheme !~/http/i;
	
    #
    # get header information on URL to see it's status (exis-
    # tant, accessible, etc.) and content type. If the status
    # is not okay or the content type is not what we are 
    # looking for skip the URL and move on
    # 

    print LOG "[HEAD ] $url\n";

    my $request  = new HTTP::Request HEAD => $url;
    my $response = $robot->request( $request );
	
    next if $response->code != RC_OK;
    next if ! &wanted_content( $response->content_type , $url);

    print LOG "[GET  ] $url\n";

    $request->method( 'GET' );
    $response = $robot->request( $request );

    next if $response->code != RC_OK;
    next if $response->content_type !~ m@text/html@;
    
    print LOG "[LINKS] $url\n";
    
    ++$extract_number;
    
    #TODO:
    &extract_vector($response->content, $url);
    &extract_content ($response->content, $url);

    my @related_urls  = &grab_urls( $response->content , $response->base);

    foreach my $link (@related_urls) {
    	my $full_url = eval { (new URI::URL $link, $response->base)->abs; };
    	    
    	delete $relevance{ $link } and next if $@;
    
    	$relevance{ $full_url } = $relevance{ $link };
    	delete $relevance{ $link } if $full_url ne $link;
    
    	push @search_urls, $full_url and $pushed{ $full_url } = 1
    	    if ! exists $pushed{ $full_url };
    }

    #
    # reorder the urls base upon relevance so that we search
    # areas which seem most relevant to us first.
    #

    @search_urls = 
	sort { $relevance{ $a } <=> $relevance{ $b }; } @search_urls;
}

#indicates if crawler has finished running
print "crawler complete\n";
#total count for the number of valid html, excluding pdf, ps, plaintext, non-local, and self-referencing
print "Total html being extracted: ". $extract_number ."\n";
#saved links to pdf and postscripts, will be printed to LINK file
print "Total postcript/pdf links: " . scalar @wanted_urls ."\n";

#print all the contents in wanted url array
for (my $i = 0; $i < scalar @wanted_urls; ++$i){
    print LINK $wanted_urls[$i] . "\n";
}
close LOG;
close CONTENT;
close LINK;
exit (0);
    
#
# wanted_content

#  this function checks to see if the current URL content
#  is something which is either
#
#    a) something we are looking for (e.g. postscript, pdf,
#       plain text, or html). In this case we should save the URL in the
#       @wanted_urls array. Only saving the pdf and postscript links.
#
#    b) something we can traverse and search for links
#       (this can be just text/html).
#

sub wanted_content {
    #print "wanted_content function\n";
    my $content = shift;
    my $url = shift;
    #print "content_type: " . $content . "\n";

    # If the content type is something we are looking for (.ps, .pdf)
    #m@text/plain@ / m@text/html@
    if ($content =~ m@application/postscript@ or $content =~ m@application/pdf@){
        #print "save\n";
        push @wanted_urls, $url;
    }
    if ($content =~ m@text/html@){
        #print "yes\n";
        return 1;
    }
    return 0;
}

#
# extract_content
#
#  this function will read through the context of all the text/html
#  documents retrieved by the web robot and extract three types of
#  contact information described in the assignment
#
#  If the contact information appears more than once, it will print 
#  all of them
#

sub extract_content {
    my $content = shift;
    my $url = shift;

    my @email = ();
    my @phone = ();
    my @city = ();

    # parse out information you want
    #get the phone information
    while ($content =~ m/(?:\+?1[-. ])?\(?([0-9]{3})\)?[-. ]([0-9]{3})[-. ]([0-9]{4})/g) {
        push @phone, $&;
    }
    #get the Email information
    while ($content =~ m/\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*/g) {
        push @email, $&;
    }
    
    #get the address information
    while ($content =~ m/\w+,\s*\w+\s[0-9]{5}/g) {
        push @city, $&;
    }
    # print it in the tuple format to the CONTENT and LOG files, for example:
    for (my $i = 0; $i < scalar @phone; ++$i){
        print CONTENT "($url; PHONE; $phone[$i])\n";
        print LOG "($url; PHONE; $phone[$i])\n";
    }
    
    for (my $i = 0; $i < scalar @email; ++$i){
        print CONTENT "($url; EMAIL; $email[$i])\n";
        print LOG "($url; EMAIL; $email[$i])\n";
    }

    for (my $i = 0; $i < scalar @city; ++$i){
        print CONTENT "($url; EMAIL; $city[$i])\n";
        print LOG "($url; EMAIL; $city[$i])\n";
    }
    return;
}

#
# grab_urls
#
#   this function parses through the content of a passed HTML page and
#   picks out all links and any immediately related text.
#
#   The relevance ranking scheme goes from 0 to 10, with decimal precision. 
#   The most relevant files would be at a lower count than the less relevant ones
#   The common words are first extracted from the total content.
#   There are three separate ways of ranking the links. One way is to check for 
#   the number of backslashes in the link. The second way is to check for junk characters
#   such as ?,=,%,&,$. the final method requires matching the words from the reg_text with
#   the existing content words on the current page. The detailed matching is in function
#   compute_relevance. We combined the relevance number output from each method and specified
#   how much weight to give to each method.

sub grab_urls {
    my $content = shift;
    my $base_url = shift;
    my %urls    = ();    # NOTE: this is an associative array so that we only
                         #       push the same "href" value once.
    

    
  skip:
    while ($content =~ s/<\s*[aA] ([^>]*)>\s*(?:<[^>]*>)*(?:([^<]*)(?:<[^aA>]*>)*<\/\s*[aA]\s*>)?//) {
    	my $tag_text = $1;
    	my $reg_text = $2;
    	my $link = "";
    	my $quality = undef;
    	my @text = ();
        #print "grab url: \n";
        #print "tag_text: " . $tag_text . "\n";
        #print "reg_text: " . $reg_text . "\n";
    	if (defined $reg_text) {
    	    $reg_text =~ s/[\n\r]/ /;
    	    $reg_text =~ s/\s{2,}/ /;
    	    
    	    my @reg_words = split(' ', $reg_text);
            for my $word (@reg_words){
                if (!exists($stoplist_hash{lc($word)})){
                    #check exist in link
                    # print lc($word),"\n";
                    push @text, lc($word);
                }
            }
    	}
    	
    	if ($tag_text =~ /href\s*=\s*(?:["']([^"']*)["']|([^\s])*)/i) {
    	    $link = $1 || $2;
    	    
    	    #we need to remove the link which is non-local or self-referencing link
            #we created the variable $domain from the host address to check for local link
            #we used the character '#' to check for self-referencing link
    	    if (defined $link and not $link =~ /#/){
    	        if(not $link =~ /[jJ]ava[sS]cript/ and not $link =~ /mailto/){ #filters output javascripts and mailto pages
                    my $furl = (new URI::URL $link)->abs( $base_url );
                    if ($furl =~ /$domain/){
                        #
                        # we need to get the "quality value" of that webpage, the "quality value"
                        # starts from 0 to 10, 0 means highest quality and 10 means lowest quality
                        # 
                        my @url_array = split("/", $furl);
                        my $slash_number = scalar @url_array - 1;
                        my $slash_quality = undef;
                        if ($slash_number <= 4){  #check number of backslashes in the url, convert to relevance
                            $slash_quality = 0;
                        }
                        elsif ($slash_number > 4 and $slash_number < 14){
                            $slash_quality = $slash_number - 4;
                        }
                        else{
                            $slash_quality = 10;
                        }
                        
                        my $junk_character_number = 0;
                        my $junk_character_quality = undef;
                        while ($furl =~ m/[?,=,%,&,\$]/g){  #check number of junk characters in url and convert to a relevance score.
                            ++$junk_character_number;
                        }
                        if ($junk_character_number == 0){
                            $junk_character_quality = 0;
                        }
                        elsif ($junk_character_number > 0 and $junk_character_number < 10){
                            $junk_character_quality = $junk_character_number;
                        }
                        else{
                            $junk_character_quality = 10;
                        }
                        
                        #returns the relevance rating based on matched reg_text
                        my $content_relevant_quality = 10 * 1 / compute_relevance($link, @text);
                        #calculates the final quality/relevance score for the link
                        $quality = int($slash_quality * 0.4 + $junk_character_quality * 0.3 + $content_relevant_quality * 0.3);
                        $relevance{ $link } = $quality;
                        #print "relevant: ". $quality. "\n";
                        #
                        
                        $urls{ $link }      = $quality;
                        print "reg_text: " . $reg_text. "\n" if defined $reg_text;
                        print "link: " . $link. "\n\n";
                    }
                    else{
                        #print "delete link: " . $link, "\n\n"
                    }
    	        }
    	    }
    	}
    }
    return keys %urls;   # the keys of the associative array hold all the
                         # links we've found (no repeats).
}

######################################################################
# COMPUTE_RELEVANCE
# This function returns a raw weight of the matched words between the
# reg_text and the hash values of all words on the base page. More matched
# would correlate to higher relevance ranking for the link in question
######################################################################
sub compute_relevance{
    my $link = shift;
    my @text = shift;
    my $relevance = 1;  #default of 1
    my $i = 0;

    for (my $i = 0; $i < scalar @text; ++$i){
        if (exists $token_vector{$i}){
            # print $i,"\n";
            $relevance += $token_vector{$i};
        }
    }
    return $relevance;
}

##############################################################################################
# EXTRACT_VECTOR
# Function parses the paragraph text and the list tag from current page. Also, the function checks
# for the page's title, meta tags description and keywords. It will save each
# individual word token into the token_vector hash by a specified weight.
###########################################################################################
sub extract_vector(){
    my $html = shift;
    my $url = shift;  #current url being checked
 
    # print $url,"\n";
    my $title = HTML::TokeParser->new(\$html);
    my $header = HTML::HeadParser->new;
    $header->parse($html);
        
    my $tree = HTML::TreeBuilder->new;
    $tree->parse($html);
 
    my @all_p = $tree->look_down(sub{ $_[0]-> tag() eq 'p' or $_[0]-> tag() eq 'li'});
    foreach my $p (@all_p) {  #p as hashes
        my $ptag = HTML::TreeBuilder->new_from_content($p->as_HTML);  #ptag as hashes
        # print $ptag,"\n";
        my $pcontents = $ptag->as_text;
        # print $pcontents,"\n";
        $pcontents = lc($pcontents);
        $pcontents =~ s/[[:punct:]]/ /g;
        $pcontents =~ s/\d/ /g;  #remove numbers as well
        my @tokens = split (/\s+/, $pcontents);
        for (my $i = 0; $i < scalar @tokens; ++$i){
            # print "paragraph/list word: ",$i,"\n";
            if (!exists $stoplist_hash{$i}){
                if (!exists $token_vector{$i}){
                    $token_vector{$i} = 1;                    
                }else{
                    $token_vector{$i} += 1;                    
                }
            }
        }
    }

    $title = $header->header('Title');
    my $description = $header->header('X-Meta-Description');
    my $keywords = $header->header('X-Meta-Keywords');

    $title = lc($title);
    #TODO:
    #$description = lc($description);
    #$keywords = lc($keywords);

    $title =~ s/[[:punct:]]/ /g;
    $description =~ s/[[:punct:]]/ /g;
    $keywords =~ s/[[:punct:]]/ /g;
    
    if (defined $title){
        my @tokens = split (/\s+/, $title);
        for (my $i = 0; $i < scalar @tokens; ++$i){
            if (!exists $stoplist_hash{$i} and $i !~ m/^untitled$/ and $i !~ m/^document$/){
                # print "title word: ",$i,"\n";
                if (!exists $token_vector{$i}){
                        $token_vector{$i} = 2;                    
                    }else{
                        $token_vector{$i} += 2;                    
                    }
            }
        }
    }
    
    if (defined $description){
        my @tokens = split (/\s+/, $description);
        for (my $i = 0; $i < scalar @tokens; ++$i){
            if (!exists $stoplist_hash{$i}){
                # print "description word: ",$i,"\n";
                if (!exists $token_vector{$i}){
                        $token_vector{$i} = 2;                    
                }else{
                    $token_vector{$i} += 2;                    
                }
            }
        }
    }
    
    if (defined $keywords){
        my @tokens = split (/\s+/, $keywords);
        for (my $i = 0; $i < scalar @tokens; ++$i){
            if (!exists $stoplist_hash{$i}){
                # print "keyword word: ",$i,"\n";
                if (!exists $token_vector{$i}){
                        $token_vector{$i} = 2;                    
                }else{
                    $token_vector{$i} += 2;                    
                }
            }
        }
    }
}
