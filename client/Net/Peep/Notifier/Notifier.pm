package Net::Peep::Notifier;

require 5.005;
use strict;
use Carp;
use Sys::Hostname;
use Data::Dumper;
use Net::Peep::Log;
use Net::Peep::Mail;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION $LOGGER 
		 $NOTIFICATIONS $NOTIFICATION_INTERVAL 
		     %NOTIFICATION_LEVEL %NOTIFICATION_RECIPIENTS
			 %NOTIFICATION_HOSTS
			     @SMTP_RELAYS $HOSTNAME $USER $FROM };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( );
@EXPORT_OK = ( );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.2 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

$LOGGER = Net::Peep::Log->new();

$NOTIFICATIONS = {}; # used for caching failsafe information
$NOTIFICATION_INTERVAL = 1800; # seconds
%NOTIFICATION_LEVEL = ( ); # see below for more information
%NOTIFICATION_RECIPIENTS = ( );
%NOTIFICATION_HOSTS = ( );
@SMTP_RELAYS = ( 'localhost' );

$HOSTNAME = hostname() ? hostname() : 'localhost';
$USER = $ENV{'USER'} ? $ENV{'USER'} : 'peep';

$FROM = "Peep Notification <$USER\@$HOSTNAME>";

sub new {

    my $self = shift;
    my $class = ref($self) || $self;
    my $this = {};
    bless $this, $class;

} # end sub new

sub _timeToSend {

    # answers the question: based on the time that the last
    # notification was sent, is it time to send another notification

    my $self = shift;
    my $client = shift;

    my $last_send_time;
    if ($self->_sendTimeExists($client)) {
	$last_send_time = $self->_getSendTime($client);
    } else {
	return 1; # if there is no send time, it's time!
    }

    my $time = time();

    if ($time - $last_send_time > $NOTIFICATION_INTERVAL) {
	return 1;
    } else {
	return 0;
    }

} # end sub _timeToSend

sub _notificationExists {

    # returns 1 if a notification has been sent for a client of the
    # type stored in the generator object, 0 otherwise

    my $self = shift;
    my $client = shift || confess "client not found";

    if (exists $NOTIFICATIONS->{$client}) {
	return 1;
    } else {
	return 0;
    }

} # end sub _notificationExists

sub _getNotificationRecipients {

    my $self = shift;
    my $client = shift || confess "client not found";

    unless (exists $NOTIFICATION_RECIPIENTS{$client}) {
	return wantarray ? () : [];
    }

    return wantarray ? @{$NOTIFICATION_RECIPIENTS{$client}} : $NOTIFICATION_RECIPIENTS{$client};

} # end sub _getNotificationRecipients

sub _getNotificationHosts {

    my $self = shift;
    my $client = shift || confess "client not found";

    unless (exists $NOTIFICATION_HOSTS{$client}) {
	return wantarray ? () : [];
    }

    return wantarray ? @{$NOTIFICATION_HOSTS{$client}} : $NOTIFICATION_HOSTS{$client};

} # end sub _getNotificationHosts

sub notify {

    my $self = shift;
    my $notification = shift || confess "notification not found";
    my $force = shift;

    my $client = $notification->client() || confess "client not found";

    if (exists $NOTIFICATION_HOSTS{$client} &&
	exists $NOTIFICATION_RECIPIENTS{$client} &&
	exists $NOTIFICATION_LEVEL{$client}) {
	unless (scalar($self->_getNotificationRecipients($client))) {
	    $LOGGER->debug(1,"Cannot notify recipients for client [$client]:  ".
			   "No recipients were specified.");
	    return 0;
	}

	my @hosts = $self->_getNotificationHosts($client);

	unless (scalar(@hosts)) {
	    $LOGGER->debug(1,"Cannot notify recipients for client [$client]:  ".
			   "No acceptable notification hosts [@hosts] were specified.");
	    return 0;
	}

	my $ok = 0;
	
	for my $host (@hosts) {
	    $LOGGER->debug(8,"Checking host [$host] against hostname [$HOSTNAME] ...\n");
	    $ok++ if $host eq $HOSTNAME;
	    $ok++ if $host =~ /^(all|localhost|127\.0\.0\.1)$/;
	    $ok = 0, last if $host eq 'none';
	}
	
	my $status = $notification->status();
	if ($NOTIFICATION_LEVEL{$client} eq 'crit' && $status ne 'crit') {
	    $LOGGER->debug(7,"Notification ignored:  Notification level is [$status].  ".
			   "Notifications are only sent at [crit].");
	    return 1;
	} elsif ($NOTIFICATION_LEVEL{$client} eq 'warn' && $status !~ /^(warn|crit)$/) {
	    $LOGGER->debug(7,"Notification ignored:  Notification level is [$status].  ".
			   "Notifications are only sent at [crit] or [warn].");
	    return 1;
	} else {
	    # do nothing
	}
	
	my $return;
	
	if ($ok) {
	    
	    eval {
		
		confess "Cannot notify recipients:  No client was specified."
		    unless $client;
		confess "Cannot notify recipients:  No mail relays were specified."
		    unless scalar(@SMTP_RELAYS);
		
		$self->store($notification);
		
		if ($self->_notificationExists($client)) {
		    if ($self->_timeToSend($client) || $force) {
			$return = $self->_notify($client);
		    } else {
			$return = 1;
		    }
		} else {
		    $return = $self->_notify($client);
		}
		
	    };

	    if ($@ || ! $return) {
		$LOGGER->log(ref($self),":  Error generating notification:  $@");
	    }
	    
	    return $return;
	    
	} else {
	    
	    $LOGGER->debug(1,"Notification ignored:  [$HOSTNAME] was not among the list of acceptable notification hosts.");
	    return 1;
	    
	}

    } else {

	$LOGGER->debug(1,"Notification ignored:  No notification information is available for client [$client].\n".
		         "\t(Possibly because no notification block was defined for the client in the Peep \n".
		         "\tconfiguration file.)");
	return 1;

    }
	
} # end sub notify

sub _notify {

    # notify the recipients of the notification
    my $self = shift;
    my $client = shift || confess "client not found";
    
    if (scalar($self->_getNotifications($client))) {

	my $mailer = Net::Peep::Mail->new();
	
	$mailer->smtp_server(@SMTP_RELAYS);
	$mailer->from("Peep Notification <$USER\@$HOSTNAME>");
	$mailer->to($self->_getNotificationRecipients($client));
	$mailer->subject("[Peep Notification] $client on $HOSTNAME");
	$mailer->body($self->_getBody($client));
	if ($mailer->send()) {
	    $self->_setSendTime($client);
	    $self->_garbageCollect($client);
	    return 1;
	} else {
	    return 0;
	}

    }

} # end sub _notify

sub _getNotifications {

    # Return only those notifications exceeding the notification
    # threshhold defined in the Peep configuration file for the
    # specified client

    my $self = shift;
    my $client = shift || confess "client not found";

    return () unless $self->_notificationExists($client);

    my $level = $NOTIFICATION_LEVEL{$client} 
        || confess "Notification level for client [$client] not found.";

    if ($level eq 'crit') {
	return grep $_->status() eq 'crit', @{$NOTIFICATIONS->{$client}->{'NOTIFICATIONS'}};
    } elsif ($level eq 'warn') {
	return grep $_->status() =~ /warn|crit/, @{$NOTIFICATIONS->{$client}->{'NOTIFICATIONS'}};
    } else {
	return @{$NOTIFICATIONS->{$client}->{'NOTIFICATIONS'}};
    }

} # end sub _getNotifications

sub _getBody {

    my $self = shift;
    my $client = shift;

    return undef unless $self->_notificationExists($client);

    my @notifications = $self->_getNotifications($client);

    my $n_notifications = scalar(@notifications);

    my $time = scalar(localtime(time()));

    my $body = <<"eop";
User:           $USER
Host:           $HOSTNAME
Client:         $client
Time:           $time
Notifications:  $n_notifications

eop

    ;

    my $i = 1;

    # reverse the order of notifications to get the most recent first
    for my $notification (reverse @notifications) {

	my $status = ucfirst($notification->status());
	my $message = $notification->message();
	my $time = scalar(localtime($notification->datetime()));

	$body .= <<"eop";
\[Notification $i:  $status at $time\]
$message

eop

    ;

	$i++;

    }

    return $body;

} # end sub _getBody

sub store {

    # store failsafe information for future reference
    my $self = shift;
    my $notification = shift; # a Net::Peep::Notification object

    my $client = $notification->client() || confess "client not found";
    push @{$NOTIFICATIONS->{$client}->{'NOTIFICATIONS'}}, $notification;

    return 1;

} # end sub store

sub _sendTimeExists {

    my $self = shift;
    my $client = shift || confess "client not found";
    
    if (exists $NOTIFICATIONS->{$client} &&
	exists $NOTIFICATIONS->{$client}->{'SEND_TIME'}) {
	return 1;
    } else {
	return 0;
    }

} # end sub _sendTimeExists

sub _setSendTime {

    my $self = shift;
    my $client = shift || confess "client not found";
    $NOTIFICATIONS->{$client}->{'SEND_TIME'} = time();

} # end sub _setSendTime

sub _getSendTime {

    my $self = shift;
    my $client = shift || confess "client not found";

    if (exists $NOTIFICATIONS->{$client}) {
	if (exists $NOTIFICATIONS->{$client}->{'SEND_TIME'}) {
	    return $NOTIFICATIONS->{$client}->{'SEND_TIME'};
	} else {
	    confess "Cannot find SEND_TIME key for client [$client]";
	}
    } else {
	return undef;
    }

} # end sub _getSendTime

sub _garbageCollect {

    # clear out old notification information

    my $self = shift;

    my $client = shift || confess "client not found";
    delete $NOTIFICATIONS->{$client}->{NOTIFICATIONS}
	if exists $NOTIFICATIONS->{$client} &&
	    exists $NOTIFICATIONS->{$client}->{NOTIFICATIONS};
    $NOTIFICATIONS->{$client}->{NOTIFICATIONS} = [];

    return 1;

} # end sub _garbageCollect

sub force {

    # clear out any unsent notifications whether or not they're ready
    # to be sent
    my $self = shift;

    my $force = 1;

    my $n;

    for my $client (keys %$NOTIFICATIONS) {
	if (exists $NOTIFICATIONS->{$client}->{'NOTIFICATIONS'} && 
	    exists $NOTIFICATIONS->{$client}->{'SEND_TIME'}) {
	    my @notifications = @{$NOTIFICATIONS->{$client}->{'NOTIFICATIONS'}};
	    $n = @notifications;
	    $self->notify($notifications[0],$force) if @notifications;
	}
    }

    return $n;

} # end sub force

sub flush {

    # clear out any unsent notifications that are ready to be sent
    my $notifier = Net::Peep::Notifier->new();

    for my $client (keys %$NOTIFICATIONS) {
	if (exists $NOTIFICATIONS->{$client}->{'NOTIFICATIONS'} && 
	    exists $NOTIFICATIONS->{$client}->{'SEND_TIME'}) {
	    my @notifications = @{$NOTIFICATIONS->{$client}->{'NOTIFICATIONS'}};
	    $notifier->notify($client);
	}
    }

} # end sub flush

1;

__END__

=head1 NAME

Net::Peep::Notifier - Utility object for Peep client event or state
e-mail notifications

=head1 SYNOPSIS

  use Net::Peep::Notifier;
  $notifier = new Net::Peep::Notifier;
  $notifier->client('logparser'); # identify who is generating notifications
  $notifier->from($from); # identify who is sending the e-mail
  $notifier->recipients(@recipients); # identify some failsafe recipients
  $notifier->relays(@relays); # identify some SMTP relays
  $notifier->notify(); # sends an e-mail if it is time, otherwise caches
                       # the information for sending later

  $john = new Net::Peep::Notifier;
  $john->flush(); # flush (send) outstanding messages as necessary

=head1 DESCRIPTION

    Utility object for notifications; for example, when logparser
    matches a root login in /var/log/messages.

    When a notification is created, the object will first check
    whether a notification has been sent for that client (based on the
    value of $NOTIFICATION_INTERVAL).

    If so, the notification information is merely noted and no
    notification is sent out.  If not, the notification information,
    as well as any previously unsent notification information, is sent
    to the recipients specified by return value of the recipients()
    method.

    The object also supports a flush method, which can be used to
    periodically flush (send out) any failsafe messages which are due
    to be sent.

    The basic idea is to populate the object attributes with pertinant
    information (e.g., a a list of recipients, a set of SMTP relays, a
    'From:' address, etc.), then call the notify method.  If a
    notification should be sent, it will be.  If not, the information
    will be cached for later use (e.g., a call to the flush() method.)

    To flush out unsent messages, simply instantiate a new
    Net::Peep::Notifier object and call the flush method.

=head2 EXPORT

None by default.

=head1 ATTRIBUTES

    $LOGGER - A Net::Peep::Log object

    $NOTIFICATIONS - Used for caching failsafe information

    $NOTIFICATION_INTERVAL - Number of seconds between each
    notification

    $NOTIFICATION_LEVEL - A hash whose keys are client names (e.g.,
    'logparser') and whose values are the level ('info', 'warn', or
    'crit') at which to issue notifications for that client.  Defaults
    to 'info'.  

    %NOTIFICATION_RECIPIENTS - A hash whose keys are client names
    (e.g., 'logparser') and whose values are arrays of e-mail
    addresses to which notifications will be sent for that client.
    Will be set to whatever is specified in the Peep configuration
    file.

    @SMTP_RELAYS - An array of SMTP servers from which e-mail
    notifications may be relayed.  Defaults to localhost.  Will we set
    to whatever is specified in the Peep configuration file.

=head1 METHODS

    new() - The constructor

    from() - A get/set method to store a 'From:' address for e-mail
    notification.  Must be set prior to calling the notify() method.

    interval() - A get/set method to store the notification interval
    (in seconds).  Defaults to $NOTIFICATION_INTERVAL.  

    recipients() - A get/set method to store an array of e-mail
    recipients.  Must be set prior to calling the notify() method.

    relays() - A get/set method to store an array of SMTP relays.
    Must be set prior to calling the notify() method.

    notify() - If applicable, notify recipients of an event or state
    via e-mail based on attributes such as generator() etc. (see
    above).  Otherwise, store the information for later reference.

    flush() - Clear out any unsent failsafe messages which have not
    been sent in at least $NOTIFICATION_INTERVAL seconds

    force() - Forcibly clear out any unsent failsafe messages whether
    or not they have been sent in at least $NOTIFICATION_INTERVAL
    seconds

=head1 AUTHOR

Collin Starkweather <collin.starkweather@colorado.edu> Copyright (C) 2001

=head1 SEE ALSO

perl(1), Net::Peep, Net::Peep::Mail

=cut
