# PGMTimer

[![CI Status](http://img.shields.io/travis/pablogm/PGMTimer.svg?style=flat)](https://travis-ci.org/pablogm/PGMTimer)
[![Version](https://img.shields.io/cocoapods/v/PGMTimer.svg?style=flat)](http://cocoapods.org/pods/PGMTimer)
[![License](https://img.shields.io/cocoapods/l/PGMTimer.svg?style=flat)](http://cocoapods.org/pods/PGMTimer)
[![Platform](https://img.shields.io/cocoapods/p/PGMTimer.svg?style=flat)](http://cocoapods.org/pods/PGMTimer)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

This is a simple class to provide a Swift Timer with the following features: start, stop, pause, resume.

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation with CocoaPods

PGMTimer is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "PGMTimer"
```

## Installation with Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency management tool written in Swift.

Add the following line to your Cartfile:

```
github "pablogm/PGMTimer"
```

## How to use

Init timer:

```swift
    timer = Timer(timerEnd: 10.0, timerWillStart: {

        print("Timer started.")
    
    }, timerDidFire: { [weak self] time in

        self?.timerLabel.text = time

    }, timerDidPause: {

        print("Timer paused")

    }, timerWillResume: {

        print("Timer resumed")

    }, timerDidStop: {

        print("Timer stopped")

    }, timerDidEnd: { [weak self] time in

        self?.timerLabel.text = time

    print("Timer End")
    })
```

Perform actions:

```swift
    @IBAction func startTimer(sender: UIButton) {

        if timer.state == .TimerStateUnkown || timer.state == .TimerStateStopped || timer.state == .TimerStateEnded {

            timer.start()
        }
        else {
            print("Can not start")
        }
    }

    @IBAction func pauseTimer(sender: UIButton) {

        if timer.state == .TimerStateRunning {

            timer.pause()
        }
        else {
            print("Can not pause")
        }
    }

    @IBAction func resumeTimer(sender: UIButton) {

        if timer.state == .TimerStatePaused {

            timer.resume()
        }
        else {
            print("Can not resume")
        }
    }

    @IBAction func stopTimer(sender: UIButton) {

        if timer.state == .TimerStateRunning {

            timer.stop()
        }
        else {
            print("Can not stop")
        }
    }
```

## Support

Supports iOS8 and above. XCode 7.0 is required to build the latest code written in Swift 2.0

## Author

Pablo GM, invanzert@gmail.com

## License

PGMTimer is available under the MIT license. See the LICENSE file for more info.
