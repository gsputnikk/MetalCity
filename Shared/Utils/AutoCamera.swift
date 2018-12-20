//
//  AutoCamera.swift
//  MetalCity
//
//  Created by Andy Qua on 19/12/2018.
//  Copyright © 2018 Andy Qua. All rights reserved.
//

import Foundation

enum CameraBehaviour : Int {
    case manual
    case flycam1
    case flycam2
    case flycam3
    case orbitInward
    case orbitOutward
    case orbitElliptical
    case speed
    case spin
}


let MAX_PITCH = 85
let FLYCAM_CIRCUT = 60000
let FLYCAM_CIRCUT_HALF = (FLYCAM_CIRCUT / 2)
let FLYCAM_LEG = (FLYCAM_CIRCUT / 4)
let ONE_SECOND = 1000
let CAMERA_CHANGE_INTERVAL = 15
let CAMERA_CYCLE_LENGTH = (10 * CAMERA_CHANGE_INTERVAL)

class AutoCamera {
    var camera : Camera
    var isEnabled : Bool = false
    var behaviour : CameraBehaviour = .manual
    var randomBehaviour = true {
        didSet {
            
        }
    }

    init( camera:Camera ) {
        self.camera = camera
        behaviour = .speed
    }
    

    func setCameraBehaviour( behaviour:CameraBehaviour ) {
        self.behaviour = behaviour
        randomBehaviour = false
    }
    
    func update() {
        appState.cameraState.cam_auto = true
        
        if appState.cameraState.cam_auto {
            doAutoCam()
        }
        
        if appState.cameraState.moving {
            appState.cameraState.movement *= 1.1
        } else {
            appState.cameraState.movement = 0.0
        }
        appState.cameraState.movement = appState.cameraState.movement.clamped(to:0.01 ... 1.0)
        
        if appState.cameraState.angle.y < 0.0 {
            appState.cameraState.angle.y = 360.0 - Float(fmod(abs(appState.cameraState.angle.y), 360.0))
        }
        
        appState.cameraState.angle.y = Float(fmod(appState.cameraState.angle.y, 360.0))
        appState.cameraState.angle.x = appState.cameraState.angle.x.clamped(to: Float(-MAX_PITCH) ... Float(MAX_PITCH))
        appState.cameraState.moving = false
        
    }
    
    
    func getPositionForTime( _ t:UInt64 ) -> float3 {
        var start : float3 = float3(0,0,0)
        var end : float3 = float3(0,0,0)
        
        let hot_zone = appState.hot_zone
        let timeInCircuit = t % UInt64(FLYCAM_CIRCUT)
        let leg = timeInCircuit / UInt64(FLYCAM_LEG)
        var delta = Float(timeInCircuit % UInt64(FLYCAM_LEG)) / Float(FLYCAM_LEG)
        switch (leg) {
        case 0:
            start = float3(hot_zone.minPoint.x, 25.0, hot_zone.minPoint.z)
            end = float3(hot_zone.minPoint.x, 60.0, hot_zone.maxPoint.z)
            break
        case 1:
            start = float3(hot_zone.minPoint.x, 60.0, hot_zone.maxPoint.z)
            end = float3(hot_zone.maxPoint.x, 25.0, hot_zone.maxPoint.z)
            break
        case 2:
            start = float3(hot_zone.maxPoint.x, 25.0, hot_zone.maxPoint.z)
            end = float3(hot_zone.maxPoint.x, 60.0, hot_zone.minPoint.z)
            break
        case 3:
            start = float3(hot_zone.maxPoint.x, 60.0, hot_zone.minPoint.z)
            end = float3(hot_zone.minPoint.x, 25.0, hot_zone.minPoint.z)
            break
        default:
            break
        }
        delta = mathScalarCurve(delta)
        return float3.lerp(vectorStart: start, vectorEnd: end, t: delta)
    }
    
    
    func doAutoCam() {
        
        let now = getTickCount()
        var elapsed = now - appState.cameraState.last_update
        elapsed = min(elapsed, 50) //limit to 1/20th second worth of time
        if elapsed == 0 {
            return
        }
        
        appState.cameraState.last_update = now
        let t = (now/1000) % UInt64(CAMERA_CYCLE_LENGTH)
        if randomBehaviour {
            if let b = CameraBehaviour(rawValue:Int(t) / CAMERA_CHANGE_INTERVAL) {
                behaviour = b
            }
        }
        appState.cameraState.tracker += Float(elapsed) / 300.0
        //behavior = .flycam1

        let worldHalf = Float(WORLD_HALF)
        var target : float3
        switch (behaviour)
        {
        case .orbitInward:
            appState.cameraState.auto_position.x = worldHalf + sinf(appState.cameraState.tracker * DEGREES_TO_RADIANS) * 150.0
            appState.cameraState.auto_position.y = 60.0
            appState.cameraState.auto_position.z = worldHalf + cosf (appState.cameraState.tracker * DEGREES_TO_RADIANS) * 150.0
            target = float3(worldHalf, 40.0, worldHalf)
            break
        case .orbitOutward:
            appState.cameraState.auto_position.x = worldHalf + sinf (appState.cameraState.tracker * DEGREES_TO_RADIANS) * 250.0
            appState.cameraState.auto_position.y = 60.0
            appState.cameraState.auto_position.z = worldHalf + cosf (appState.cameraState.tracker * DEGREES_TO_RADIANS) * 250.0
            target = float3 (worldHalf, 30.0, worldHalf)
            break
        case .orbitElliptical:
            let dist = 150.0 + sinf (appState.cameraState.tracker * DEGREES_TO_RADIANS / 1.1) * 50
            appState.cameraState.auto_position.x = worldHalf + sinf (appState.cameraState.tracker * DEGREES_TO_RADIANS) * dist
            appState.cameraState.auto_position.y = 60.0
            appState.cameraState.auto_position.z = worldHalf + cosf (appState.cameraState.tracker * DEGREES_TO_RADIANS) * dist
            target = float3 (worldHalf, 50.0, worldHalf)
            break
        case .flycam1, .flycam2, .flycam3:
            appState.cameraState.auto_position = (getPositionForTime(now) + getPositionForTime(now + 4000)) / 2.0
            target = getPositionForTime(now + UInt64(FLYCAM_CIRCUT_HALF - ONE_SECOND) * 3)
            break
        case .speed:
            appState.cameraState.auto_position = (getPositionForTime(now) + getPositionForTime(now + 500)) / 2.0
            target = getPositionForTime(now + UInt64(ONE_SECOND) * 5)
            appState.cameraState.auto_position.y /= 2
            target.y /= 2
            break
        default:
            target = float3(worldHalf + sinf (appState.cameraState.tracker * DEGREES_TO_RADIANS) * 300.0,
                30.0,
                worldHalf + cosf (appState.cameraState.tracker * DEGREES_TO_RADIANS) * 300.0)
            appState.cameraState.auto_position.x = worldHalf + sinf(appState.cameraState.tracker * DEGREES_TO_RADIANS) * 50.0
            appState.cameraState.auto_position.y = 60.0
            appState.cameraState.auto_position.z = worldHalf + cosf (appState.cameraState.tracker * DEGREES_TO_RADIANS) * 50.0
        }
        
        
        camera.setPosition(pos:appState.cameraState.auto_position)
        camera.setView(view:target)
    }
    
    
    /*-----------------------------------------------------------------------------
     This will take linear input values from 0.0 to 1.0 and convert them to
     values along a curve.  This could also be acomplished with sin (), but this
     way avoids converting to radians and back.
     -----------------------------------------------------------------------------*/
    
    func mathScalarCurve( _ origVal:Float ) -> Float {
        
        var val = (origVal - 0.5) * 2.0
        let sign : Float = val < 0 ? -1 : 1
        if val < 0.0 {
            val = -val
        }
        val = 1.0 - val
        val *= val
        val = 1.0 - val
        val *= sign
        val = (val + 1.0) / 2.0
        return val
        
    }
}
