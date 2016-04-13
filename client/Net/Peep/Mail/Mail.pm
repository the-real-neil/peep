package Net::Peep::Mail;

require 5.005;
use strict;
use Carp;
use Data::Dumper;
use Net::SMTP;
use Net::Peep::Log;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION $LOGGER };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( );
@EXPORT_OK = ( );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

$LOGGER = Net::Peep::Log->new();

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;

} # end sub new

sub to {

    my $self = shift;
    $self->{'_TO'} = [] unless exists $self->{'_TO'};
    if (@_) { my @to = @_; $self->{'_TO'} = \@to; }
    return wantarray ? @{$self->{'_TO'}} : $self->{'_TO'};

} # end sub to

sub from {

    my $self = shift;
    if (@_) { $self->{'_FROM'} = shift; }
    return $self->{'_FROM'};

} # end from

sub smtp_server {

    my $self = shift;
    $self->{'_SMTP_SERVER'} = [] unless exists $self->{'_SMTP_SERVER'};
    if (@_) { my @smtp_server = @_; $self->{'_SMTP_SERVER'} = \@smtp_server; }
    return wantarray ? @{$self->{'_SMTP_SERVER'}} : $self->{'_SMTP_SERVER'};

} # end sub smtp_server

sub timeout {

    my $self = shift;
    if (@_) { $self->{'_TIMEOUT'} = shift; }
    return $self->{'_TIMEOUT'};

} # end timeout

sub subject {

    my $self = shift;
    if (@_) { $self->{'_SUBJECT'} = shift; }
    return $self->{'_SUBJECT'};

} # end subject

sub body {

    my $self = shift;
    if (@_) { $self->{'_BODY'} = shift; }
    return $self->{'_BODY'};

} # end body

sub send {

    my $self = shift;

    my $from = $self->from();
    my $to = join ', ', $self->to();
    my $subject = $self->subject();
    my $body = $self->body();

    my $data = <<"eop";
To:  $to
From:  $from
Subject:  $subject

$body
eop
    ;

    my $delivered = 0;

    $LOGGER->debug(7,"Sending e-mail:");
    $LOGGER->debug(7,$data);
    $LOGGER->debug(7,"Trying SMTP servers [".(join ', ', $self->smtp_server())."] ...");

    for my $smtp_server ($self->smtp_server()) {

	my @smtp_args = $self->timeout() 
	    ? ( $smtp_server, Timeout => $self->timeout() ) 
		: ( $smtp_server );

	my $smtp = Net::SMTP->new(@smtp_args);

	$LOGGER->debug(7,"Sending e-mail to [$smtp_server] ...");

	$LOGGER->log("Error instantiating Net::SMTP object.  ".
		     "The SMTP server [$smtp_server] may not be accepting mail relay requests.") 
	    and next unless defined $smtp;

	if ($smtp->mail($from) &&
	    $smtp->to($self->to()) &&
	    $smtp->data() &&
	    $smtp->datasend($data) &&
	    $smtp->dataend()) {
	    $delivered++;
	} 

	$smtp->quit();

	$LOGGER->debug(7,"E-mail successfully sent.") and last if $delivered;

    }

    unless ($delivered) {
	$LOGGER->log("Error delivering mail to server(s) [".join(',',$self->smtp_server())."].");
    }

    return $delivered;

} # end sub send

1;

__END__

=head1 NAME

Net::Peep::Mail - Utility object for e-mail notifications

=head1 SYNOPSIS

  use Net::Peep::Mail;
  $mail = new Net::Peep::Mail;
  $mail->smtp_server(@servers);
  $mail->timeout(15); # seconds.  (Optional)
  $mail->to(@to);
  $mail->from($from);
  $mail->subject($subject);
  $mail->body($body);
  $mail->send();

=head1 DESCRIPTION

Utility object for e-mail notifications.  It is primarily a wrapper
for the Net::SMTP object.

Loops through SMTP servers and e-mail addresses until mail has been
successfully sent to all recipients or the SMTP server list is
exhausted and logs any failures.

=head2 EXPORT

None by default.

=head1 ATTRIBUTES

    $LOGGER - A Net::Peep::Log object.

=head1 METHODS

    new() - The constructor

    to($to0,[$to1,...]) - Get/set method.  The recipient of the
    e-mail.  Must be a valid e-mail address.  Can be a list.

    from([$from]) - Get/set method.  The sender of the e-mail.  Must
    be a valid e-mail address.

    smtp_server([$smtp_server]) - Get/set method.  The SMTP server
    through which e-mails will be routed.  May be a list, in which
    case each server will be tried until delivery is successful.

    timeout([$timeout]) - Get/set method.  Controls the number of
    seconds before timeout.  Must be an integer.  Default 15.

    subject([$subject]) - Get/set method.  The e-mail subject.

    body([$body]) - Get/set method.  The body of the e-mail.

    send() - Send an e-mail or e-mails based on the to(), from(), and
    smtp_server() attributes.  Logs any failures with a
    Net::Peep::Log object.

=head1 AUTHOR

Collin Starkweather <collin.starkweather@colorado.edu> Copyright (C) 2001

=head1 SEE ALSO

perl(1), Net::SMTP, Net::Peep::Log.

=cut
