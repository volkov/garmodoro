using Toybox.Application as App;
using Toybox.Attention as Attention;
using Toybox.WatchUi as Ui;
using Toybox.ActivityRecording;

var timer;
var tickTimer;
var session;
var minutes = 0;
var pomodoroNumber = 1;
var isPomodoroTimerStarted = false;
var isBreakTimerStarted = false;
var expectBreak = false;

function ping( dutyCycle, length ) {
	if ( Attention has :vibrate ) {
		Attention.vibrate( [ new Attention.VibeProfile( dutyCycle, length ) ] );
	}
}

function play( tone ) {
	if ( Attention has :playTone && ! App.getApp().getProperty( "muteSounds" ) ) {
		Attention.playTone( tone );
	}
}

function isLongBreak() {
	return ( pomodoroNumber % App.getApp().getProperty( "numberOfPomodorosBeforeLongBreak" ) ) == 0;
}

function resetMinutes() {
	minutes = App.getApp().getProperty( "pomodoroLength" );
}

class GarmodoroDelegate extends Ui.BehaviorDelegate {
	function initialize() {
		Ui.BehaviorDelegate.initialize();
		timer.start( method( :idleCallback ), 60 * 1000, true );
	}

	function pomodoroCallback() {
		minutes -= 1;

		if ( minutes == 0 ) {
			play( 10 ); // Attention.TONE_LAP
			ping( 100, 1500 );
			expectBreak = true;
		}
		if (minutes < 0) {
			ping( 50, 500 );
			expectBreak = true;
		}

		Ui.requestUpdate();
	}

	function goBreak() {
		tickTimer.stop();
		timer.stop();
		isPomodoroTimerStarted = false;
		expectBreak = false;
		minutes = App.getApp().getProperty( isLongBreak() ? "longBreakLength" : "shortBreakLength" );

		timer.start( method( :breakCallback ), 60 * 1000, true );
		isBreakTimerStarted = true;
		session.stop();
		session.save();
		session = null;
	}

	function breakCallback() {
		minutes -= 1;

		if ( minutes == 0 ) {
			play( 7 ); // Attention.TONE_INTERVAL_ALERT
			ping( 100, 1500 );
			timer.stop();

			isBreakTimerStarted = false;
			pomodoroNumber += 1;
			resetMinutes();
			timer.start( method( :idleCallback ), 60 * 1000, true );
		}

		Ui.requestUpdate();
	}

	function idleCallback() {
		Ui.requestUpdate();
	}

	function shouldTick() {
		return App.getApp().getProperty( "tickStrength" ) > 0;
	}

	function tickCallback() {
		ping( App.getApp().getProperty( "tickStrength" ), App.getApp().getProperty( "tickDuration" ) );
	}

	function onBack() {
		Ui.popView( Ui.SLIDE_RIGHT );
		return true;
	}

	function onNextMode() {
		return true;
	}

	function onNextPage() {
		return true;
	}

	function onSelect() {
		if ( expectBreak ) {
			goBreak();
			Ui.requestUpdate();
			return true;
		}
		if ( isBreakTimerStarted || isPomodoroTimerStarted ) {
			Ui.pushView( new Rez.Menus.StopMenu(), new StopMenuDelegate(), Ui.SLIDE_UP );
			return true;
		}

		play( 1 ); // Attention.TONE_START
		ping( 75, 1500 );
		timer.stop();
		resetMinutes();
		timer.start( method( :pomodoroCallback ), 60 * 1000, true );
		if ( me.shouldTick() ) {
			tickTimer.start( method( :tickCallback ), 1000, true );
		}
		startActivity();
		isPomodoroTimerStarted = true;

		Ui.requestUpdate();

		return true;
	}

	function startActivity() {
		if ( Toybox has :ActivityRecording ) {
			session = ActivityRecording.createSession( {
				:name => "Pomodoro",
				:sport => ActivityRecording.SPORT_GENERIC,
				:subSport => ActivityRecording.SUB_SPORT_GENERIC
			} );
			session.start();
		}
	}
}
