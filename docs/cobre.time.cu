
/// times elapsed time in milliseconds
type timer;

/// Duration with millisecond precision. Cannot handle more than 30 minutes.
type duration;

/// Moment in universal time with second precision.
type date;

timer new$timer ();

/// always restarts the timer
void start$timer (timer);

/// does nothing if already stopped
void stop$timer (timer);

/// returns the elapsed time after stopped. Error if not stopped.
duration duration$get$timer (timer);

duration new$duration (int seconds, int milliseconds);
int seconds$get$duration (duration);
int milliseconds$get$duration (duration);

/// Current time reported by the system
date now ();
date new$date (int year, int day, int second);

int year$get$date (date);
int day$get$date (date);
int second$get$date (date);