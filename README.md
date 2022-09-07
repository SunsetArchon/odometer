Odometer
========

Odometer is a Javascript and CSS library for smoothly transitioning numbers.

### [Overview](http://github.hubspot.com/odometer/docs/welcome)

This is a modified fork of the original repository in response to the concerns brought up in
[Issue #111](https://github.com/HubSpot/odometer/issues/111), which requests support for time
format HH:MM:SS.

While getting the numbers formatted as such is as easy as concatenating the
hours, minutes, and seconds together into a string, the issue with the original repository is that
when counting up from 59 to 00 or down from 00 to 59, the odometer would unnecessarily flip through
numbers 60 through 99, creating an unnecessarily long animation. This repository works to resolve
this issue and provide custom functionality to how odometer digits rollover.

### [Docs and Demo](http://github.hubspot.com/odometer)

[Countdown Timer](https://sunsetarchon.github.io/odometer/test/countdown.html) - For source, see [test/countdown.html](./test/countdown.html)
