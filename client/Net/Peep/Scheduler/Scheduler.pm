package Net::Peep::Scheduler;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility
use Carp;
use Data::Dumper;
use Time::HiRes qw{ tv_interval gettimeofday alarm };
use Net::Peep::Log;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.3 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

# structure of an event
# $entry = {
#  'application' => The application name
#  'schedule_time' => the time for wakeup
#  'type' => the type of event
#  'data' => the data to pass to the handler
#  'handler' => the handler to invoke
# }

# The scheduled event queue
use vars qw( @scheduler_queue );

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = { };
	bless $this, $class;

	# Init the scheduler
	$this->logger()->debug(8, "Registering scheduler and scheduling alarm ...");
	$SIG{'ALRM'} = sub { $this->schedulerWakeUp };

	return $this;

} #end sub new

# returns a logging object
sub logger {

	my $self = shift;
	unless ( exists $self->{'__LOGGER'} ) { $self->{'__LOGGER'} = new Net::Peep::Log }
	return $self->{'__LOGGER'};

} #end sub logger

sub schedulerAddEvent {

	my ($self, $app, $sleepsec, $sleepusec, $type, $handler, $data, $repeated) = @_;

	# Do some sanity checking
	confess "Error: No application name given to scheduler when adding event." unless $app;
	confess "Error: Wakeup given to scheduler is in the past." unless $sleepsec > 0.0 || $sleepusec > 0.0;
	confess "Error: No scheduled event type given to scheduler when adding event." unless $type;
	confess "Error: No handler given to scheduler when adding event." unless $handler;

	my ($s, $usec) = gettimeofday();

	my $entry = {
		'application' => $app,
		'sleepsec' => $sleepsec,
		'sleepusec' => $sleepusec,
		'schedule_time' => [ $s + $sleepsec, $usec + $sleepusec ],
		'type' => $type,
		'data' => $data,
		'handler' => $handler,
		'repeated' => $repeated,
	};

	# Add the entry into the scheduler queue and sort by time
	push @scheduler_queue, $entry;
	@scheduler_queue = sort {
		my ($asec, $ausec) = @{ $a->{'schedule_time'} };
		my ($bsec, $busec) = @{ $b->{'schedule_time'} };
		$asec + 0.000001 * $ausec  <=> $bsec + 0.000001 * $busec;
	} @scheduler_queue;

	# Now sleep for the new time
	$self->schedulerSleep;

} #end sub schedulerAddEvent

sub schedulerRemoveEventsForApp {

	# Removes all entries in the scheduler queue for an application

	my $self = shift;
	my $app = shift || die "Application name not found!";

	@scheduler_queue = grep ! $_->{'app'} eq $app, @scheduler_queue;
		

} # end sub schedulerRemoveEventsForApp

sub schedulerGetEvent {

	my $self = shift;
	return (shift @scheduler_queue);

} #end sub schedulerGetEvent

sub schedulerCalcSleepTime {

	my $self = shift;
	my $nextent = $scheduler_queue[0];

	# Check if we have an empty queue
	unless ( $nextent ) { return undef; }

	my $sleeptime = tv_interval ( [ gettimeofday() ], $nextent->{'schedule_time'} );
	return $sleeptime;

} #end sub schedulerCalcSleepTime

sub schedulerSleep {

	my ($self, $time) = @_;
	my $sleeptime = $time || $self->schedulerCalcSleepTime;

	# Check if there's no such sleep time at this moment
	unless ( $sleeptime ) { return undef; }

	$self->logger()->debug(8, "Scheduler will wake up in $sleeptime seconds.");
	alarm ( $sleeptime );
	return $sleeptime;

} #end sub schedulerSleep

sub schedulerExplicitWakeUp {

	my $self = shift;
	$self->logger()->debug(8, "Scheduler received explicit wake up...");
	$self->schedulerWakeUp;

} #end sub schedulerExplicitWakeUp

sub schedulerWakeUp {

	my $self = shift;
	$self->logger()->debug(8, "Scheduler woke up.");
	my $entry = $self->schedulerGetEvent;

# Doesn't apply because a schedulerExplicitWakeUp call would violate this and
# still be valid
#
#	# Check that the time has past
#	unless ( &Time::HiRes::tv_interval ( [ &Time::HiRes::gettimeofday() ], $entry->{'schedule_time'}) < 0.0 ) {
#		$self->logger()->debug(8, "Scheduled event was premature - returned error.");
#		return "Error: Scheduler woke up prematurely.";
#	}

	# Check if this is an internal housekeeping entry
	# Otherwise, pass control and data to the handler
	if ($entry->{'application'} eq '__SCHEDULER') {
		# internal processing - reserved for future use
		$self->logger()->debug(8, "Processing internal event...");
	}
	else {
		# Otherwise, call the handler with arguments of the type
		# of scheduled event and the data associated
		$self->logger()->debug(8, "Invoking event handler for ". $entry->{'application'}. " of type ". $entry->{'type'}. " ...");
		&{ $entry->{'handler'} } ( $entry->{'type'}, $entry->{'data'} );
		if ($entry->{'repeated'}) {

			# if it's a repeated event, it should
			# reschedule itself

			# note that repeated events don't happen
			# precisely every sleepsec + 0.000001 *
			# sleepusec because of a delay every cycle
			# imposed by the execution time of the handler

			$self->schedulerAddEvent(
				$entry->{'application'},
				$entry->{'sleepsec'},
				$entry->{'sleepusec'},
				$entry->{'type'},
				$entry->{'handler'},
				$entry->{'data'},
				$entry->{'repeated'}
			);

			# Return because we already called the scheduler function
			# when adding the event
			return;
		}
	}

	# Reassign ourselves before we exit
	$SIG{'ALRM'} = sub { $self->schedulerWakeUp };
	$self->schedulerSleep;

} #end sub schedulerWakeUp

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Net::Peep::Scheduler - Perl extension for scheduling events
for Peep, the Network Auralizer.

=head1 SYNOPSIS

  use Net::Peep::Scheduler;
  my $scheduler = new Net::Peep::Scheduler;

  $scheduler->schedulerAddEvent(
    'test_program', 6, 0, 'test_event', \&handler, $data);

  $scheduler->schedulerExplicitWakeUp();

=head1 DESCRIPTION

Net::Peep::Scheduler provides methods for scheduling events
to run concurrently, using sigalarm. The scheduler makes use of
Time::HiRes to allow scheduling of events up to microsecond
accuracy. Scheduled events will always be played in order
of soonest scheduled time, regardless of the order the events
were fed to the scheduler.

Note that this module also defines its own debugging level - 8.
That's one notch below 'Whoa Nelly', so use with extreme
prejudice.

=head2 EXPORT

None by default.

=head2 CLASS ATTRIBUTES

  $VERSION - The CVS revision of this module.

=head2 PUBLIC METHODS

  new() - Net::Peep::Scheduler constructor.

  schedulerAddEvent($app_name, $future_secs, $future_usecs,
                    $type, $handler_coderef, $handler_data)
  Schedules an event for $future_secs seconds and
  $future_usecs microseconds in the future. When the event
  occurs, the $handler_coderef is executed and passed
  whatever data is referenced by $handler_data. The
  application should also identify itself via $app_name and
  register the type of event with $type.

  scheduleExplicitWakeUp() - Tells the scheduler explicitly
  to wake up and execute the closest scheduled event.

=head1 AUTHOR

Michael Gilfix <mgilfix@eecs.tufts.edu> Copyright (C) 2001

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::BC, Net::Peep::Client,
Net::Peep::Log.

http://peep.sourceforge.net

=head1 CHANGE LOG

$Log: Scheduler.pm,v $
Revision 1.3  2002/10/24 02:33:01  mgilfix
  Elaborated the return statement with a comment.

Revision 1.2  2002/10/24 02:30:07  starky
Added a line to the schedulerWakeUp() method to prevent redundant
handler execution.

Revision 1.1  2001/10/18 06:01:34  starky
Initial commit of client libraries for version 0.5.0.

Revision 1.2  2001/08/08 20:17:57  starky
Check in of code for the 0.4.3 client release.  Includes modifications
to allow for backwards-compatibility to Perl 5.00503 and a critical
bug fix to the 0.4.2 version of Net::Peep::Conf.

Revision 1.1  2001/06/04 06:53:09  starky
A scheduler for events requiring the sigalrm signal for handling.  See
the PODs for more detail.


=cut
