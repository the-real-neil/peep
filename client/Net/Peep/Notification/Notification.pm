package Net::Peep::Notification;

require 5.005;
use strict;
use Carp;
use Data::Dumper;
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

sub message {

    my $self = shift;
    if (@_) { $self->{_MESSAGE} = shift; }
    return $self->{_MESSAGE};

} # end sub message

sub status {

    my $self = shift;
    if (@_) { $self->{_STATUS} = shift; }
    return $self->{_STATUS};

} # end sub status

sub datetime {

    my $self = shift;
    if (@_) { $self->{_DATETIME} = shift; }
    return $self->{_DATETIME};

} # end sub datetime

sub client {

    my $self = shift;
    if (@_) { $self->{_CLIENT} = shift; }
    return $self->{_CLIENT};

} # end sub client

sub hostname {

    my $self = shift;
    if (@_) { $self->{_HOSTNAME} = shift; }
    return $self->{_HOSTNAME};

} # end sub hostname

1;

__END__

=head1 NAME

Net::Peep::Notification - A Peep notification

=head1 SYNOPSIS

  use Sys::Hostname;
  use Net::Peep::Notification;
  $notification = new Net::Peep::Notification;
  $notification->client($client); # e.g., logparser
  $notification->message($message); # the notification message
  $notification->status('info'); # or warn or crit
  $notification->datetime(time()); # the time in epoch seconds
  $notification->hostname(hostname()); # the host on which the client runs

=head1 DESCRIPTION

    This object contains attributes which define a notification.

    A notification is generated when criteria defined in the Peep
    configuration file is met, such as when load exceeds 2.5 or a
    syslog entry indicates a media failure.

=head2 EXPORT

None by default.

=head1 ATTRIBUTES

    $LOGGER - A Net::Peep::Log object

=head1 METHODS

    new() - The constructor

    client() - A get/set method to store the name of the client (for
    example, logparser) which is generating the notification.

    message() - A get/set method to store the message associated with
    the notification (for example, "Load is 2.72").

    datetime() - A get/set method to store the time at which the
    notification was generated.  The time should be in epoch seconds,
    such as is returned by the time() function in Perl.

    status() - A get/set method.  Stores one of 'info', 'warn', or
    'crit'.

    hostname() - A get/set method to store the hostname of the client
    generating the notification.

=head1 AUTHOR

Collin Starkweather <collin.starkweather@colorado.edu> Copyright (C) 2001

=head1 SEE ALSO

perl(1), Net::Peep, Net::Peep::Notifier

=cut
