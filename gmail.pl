#!/usr/bin/perl

use strict;
use warnings;

# required modules
use Net::IMAP::Simple;  # >$ cpan, >$ force install Net::IMAP::Simple
use Email::Simple;  # >$ cpan, >$ force install Email::Simple
use IO::Socket::SSL;
use HTML::TreeBuilder;
use HTML::FormatText;
use HTML::FormatText::WithLinks;

# reads and writes to txt the from, subject, date, and body text/html 
my %email_vector = ();
my $outfile = 'email_read.txt';

# fill in your details here
my $username = 'wangshilianghit@gmail.com';
my $password = 'wodeyiqie@111';
my $mailhost = 'pop.gmail.com';

# Connect
my $imap = Net::IMAP::Simple->new(
    $mailhost,
    port    => 993,
    use_ssl => 1,
) || die "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";

# Log in
if ( !$imap->login( $username, $password ) ) {
    print STDERR "Login failed: " . $imap->errstr . "\n";
    exit(64);
}
# Look in the the INBOX
my $nm = $imap->select('INBOX');

# How many messages are there?
my ($unseen, $recent, $num_messages) = $imap->status();
print "unseen: $unseen, recent: $recent, total: $num_messages\n\n";

# Used for saving data later
my $temp_data = "";

## Iterate through all messages
for ( my $i = 1 ; $i <= $nm ; $i++ ) {
    my $filter_regex = 'DailyGood';
    my $junk1_regex = 'AfterCollege\sJobs';
    my $junk2_regex = 'Squid\sDigest';
    my $junk3_regex = 'Baltimore\sRescue\sMission';
    my $junk4_regex = 'Internships\.com';
    my $junk5_regex = 'YouTube';
    my $junk6_regex = 'TIME.com';
    
    my $filter_content = _header_from($i);  #currently using the from info of a header for filtering
    # my $filter_content = _header_subject($i);  #currently using the subject info of a header for filtering
    if (_email_filter($junk6_regex, $filter_content)){
        # $temp_data = $temp_data. "zzz_From : ". _header_from($i) . "\n";
        # $temp_data .= "zzz_Subject : ". _header_subject($i). "\n";
        # my $email_body = _email_body($i);
        # $email_body = _body_filter($body_start_regex, $body_end_regex, $email_body);
        # my $email_body_translated = _translate_html($email_body);
        # $temp_data .= "zzz_Body : " . $email_body_translated. "\n";

        # $temp_data .= "\n";
        _move_to_trash($i);
        # _delete($i);
    }
    if (_email_filter($junk3_regex, $filter_content)){
        _move_to_trash($i);
    }
    if (_email_filter($junk4_regex, $filter_content)){
        _move_to_trash($i);
    }
    if (_email_filter($junk5_regex, $filter_content)){
        _move_to_trash($i);
    }    
}

open(OUTFILE, ">$outfile");
print OUTFILE "$temp_data";
close(OUTFILE);

# Disconnect
$imap->quit;
exit;

sub _translate_html {
    my $html = shift;

    # formatting html not including links
    # my $html_tree = new HTML::TreeBuilder;
    # $html_tree->parse($html);
    # my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
    # my $html_formatted = $formatter->format($html_tree);

    my $f = HTML::FormatText::WithLinks->new();
    my $html_formatted = $f->parse($html);

    return $html_formatted;
}

# filters on which email to take a look at
sub _email_filter {
    my $regex = shift;
    my $content = shift;

    return ($content =~ m/$regex/);
}

# filters on which part of the body of the email to keep
sub _body_filter {
    my $start_regex = shift;
    my $end_regex = shift;
    my $content = shift;

    $content =~ s/.+?$start_regex//gsm;
    $content =~ s/$end_regex.+$//gsm;

    return $content;
}

sub _header_from{
    my $message_number = shift;

    my $es = Email::Simple->new( join '', @{ $imap->top($message_number) } );
    my $header_from = $es -> header('From');

    return $header_from;
}

sub _header_subject{
    my $message_number = shift;

    my $es = Email::Simple->new( join '', @{ $imap->top($message_number) } );
    my $header_subject = $es -> header('Subject');

    return $header_subject;
}

sub _email_body{
    my $message_number = shift;

    my $email_body = $imap->get($message_number);

    return $email_body;
}

#does not work
sub _move_to_starred {
    my $message_number = shift;

    print "message number is : ".$message_number."\n";

    $imap->copy($message_number, '[Gmail]/Starred');
}

sub _move_to_trash {
    my $message_number = shift;

    #Gmail special folder names
    # 'Inbox'   => 'Inbox',
    # 'AllMail' => '[Gmail]/All Mail',
    # 'Trash'   => '[Gmail]/Trash',
    # 'Drafts'  => '[Gmail]/Drafts',
    # 'Sent'    => '[Gmail]/Sent Mail',
    # 'Spam'    => '[Gmail]/Spam',
    # 'Starred' => '[Gmail]/Starred'

    print "Are you sure about move the message to trash?[y/n]","\n";
    my $trash_me = <STDIN>;
    chomp $trash_me;

    print "message number is : ".$message_number."\n";
    if ($trash_me =~ m/y/){
        # $imap->add_flags($message_number, qw(\Seen \Deleted)) or die $imap->errstr;
        $imap->copy($message_number, '[Gmail]/Trash');
        print "deleted message num: ".$message_number."\n";
    }
}

# for permanently deleting email, not working
sub _delete {
    my $message_number = shift;

    print "Are you sure about permanently deleting the message?[y/n]","\n";
    my $delete = <STDIN>;
    chomp $delete;
    if ($delete =~ m/y/){
        $imap->delete($message_number);
    } 
}
