/*
Copyright (c) 2015 Pablo GM <invanzert@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

import Foundation

public typealias TimerWillStart    = () -> ()
public typealias TimerDidFire      = (time: String) -> ()
public typealias TimerDidPause     = () -> ()
public typealias TimerWillResume   = () -> ()
public typealias TimerDidStop      = () -> ()
public typealias TimerDidEnd       = (time: String) -> ()


public enum TimerState {
    
    case TimerStatePaused
    case TimerStateRunning
    case TimerStateStopped
    case TimerStateEnded
    case TimerStateUnkown
}

@objc public class PGMTimer : NSObject {
    
    public var state:TimerState             = .TimerStateUnkown
    
    private var timer: NSTimer!
    private var interval: NSTimeInterval    = 0.05
    private var timerEnd: NSTimeInterval
    private var timeCount: NSTimeInterval   = 0.0
    private var diff: NSTimeInterval        = 0.0
    
    private var timerWillStart: TimerWillStart!
    private var timerDidFire: TimerDidFire!
    private var timerDidPause: TimerDidPause!
    private var timerWillResume: TimerWillResume!
    private var timerDidStop: TimerDidStop!
    private var timerDidEnd: TimerDidEnd!
    
    
    // MARK: Init / Deinit
    
    public init(timerEnd: NSTimeInterval, timerWillStart: TimerWillStart, timerDidFire: TimerDidFire, timerDidPause: TimerDidPause, timerWillResume: TimerWillResume, timerDidStop: TimerDidStop, timerDidEnd: TimerDidEnd)
    {
        self.timerEnd           = timerEnd
        
        self.timerWillStart     = timerWillStart
        self.timerDidFire       = timerDidFire
        self.timerDidPause      = timerDidPause
        self.timerWillResume    = timerWillResume
        self.timerDidStop       = timerDidStop
        self.timerDidEnd        = timerDidEnd
    }
    
    deinit {
        
        timer?.invalidate()
        timer = nil
    }
    
    
    // MARK: Start - Pause - Resume - Stop
    @objc public func start(tmr : NSTimer? = nil)
    {
        if timer == nil {
            
            timerWillStart()
            timer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: #selector(PGMTimer.fire), userInfo: nil, repeats: true)
        }
        else {
            
            fire()
        }
        
        state = .TimerStateRunning
    }
    
    public func pause()
    {
        guard timer != nil else {
            fatalError("Timer not initialized")
        }
        
        diff = timer.fireDate.timeIntervalSinceDate(NSDate())
        timer.invalidate()
        timer = nil
        
        state = .TimerStatePaused
        
        timerDidPause()
    }
    
    public func resume()
    {
        guard timer == nil else {
            fatalError("Timer should have been invalidated before resuming")
        }
        
        state = .TimerStateRunning
        
        timerWillResume()
        
        NSTimer.scheduledTimerWithTimeInterval(diff, target: self, selector: #selector(PGMTimer.start(_:)), userInfo: nil, repeats: false)
        diff = 0.0
    }
    
    public func stop()
    {
        guard timer != nil else {
            fatalError("Timer not initialized")
        }
        
        reset()
        
        timer.invalidate()
        timer = nil
        
        state = .TimerStateStopped
        
        timerDidStop()
    }
    
    
    // MARK: Reset
    
    public func reset() {
        
        diff        = 0.0
        timeCount   = 0.0
    }
    
    
    // MARK: Fire
    
    @objc public func fire()
    {
        timeCount = timeCount + interval
        
        if timeCount >= timerEnd {
            
            timer.invalidate()
            timer = nil
            
            state = .TimerStateEnded
            
            timerDidEnd(time: timeString(timeCount))
            
            reset()
        }
        else {
            timerDidFire(time: timeString(timeCount))
        }
    }
    
    
    // MARK: Helpers
    
    func timeString(time:NSTimeInterval) -> String {
        
        let minutes         = Int(time) / 60
        let seconds         = time - Double(minutes) * 60
        let secondsFraction = seconds - Double(Int(seconds))
        
        return String(format:"%02i:%02i.%01i", minutes, Int(seconds), Int(secondsFraction * 10.0))
    }
}