# Bug catcher, Dev System. 9 September 2026

Until today this app had no way to tell anybody it was broken. It had never written a
single row to the estate's bug log. Four things changed.

**The library it loads can now be seen inside.** The Supabase script was loaded without
the one attribute that lets the browser hand us the error detail. Without it, anything
failing inside that library arrives as the two words "Script error." with no file and no
line. Five of the eight open bugs across the estate are exactly that. Count of that
attribute went from 1 to 2, and the first one was on a font tag, never a script.

**Bad weather is no longer filed as a bug.** Two rules. A developer's own preview on
their machine writes nothing at all. A dropped internet connection collapses to one
entry every ten minutes, counted per app rather than per table, because the old shape
logged once per table and twenty tables dropping at once read as a disaster. Proven:
twenty tables failing together wrote one entry, while three genuinely different faults
still wrote three.

**The system now tests itself once a day, per person, quietly.** When somebody signs in,
the 63 check self test runs in the background and the score is filed. Nobody is shown
anything and nothing is blocked. A red check on somebody's phone is seen within the hour,
and a day with no score at all is itself a warning.

**Anyone can say what they saw.** A Report a problem box on the System page. It refuses
anything too short and refuses anything that looks like a password.

One deliberate change from the brief: the box was specified for the Settings panel. That
panel is shared code that another chat edited today, so it went on the System page, which
this system owns on its own. Editing shared code to add something that has a safe home of
its own is how two chats undo each other.

Checks: syntax passes, guard.py passes, self test 63 of 63 twice on a phone width and
twice on a desktop width. Branch only. Nothing merged.
