import AppKit

struct RatPose {
    let bodyBob: CGFloat
    let headBob: CGFloat
    let frontLift: CGFloat
    let rearLift: CGFloat
    let tailLift: CGFloat
}

enum RatRenderer {
    static let poses: [RatPose] = [
        RatPose(bodyBob: 0.0, headBob: 0.0, frontLift: 0.5, rearLift: -2.0, tailLift: 0.5),
        RatPose(bodyBob: -0.4, headBob: -0.3, frontLift: -1.8, rearLift: 0.8, tailLift: 1.8),
        RatPose(bodyBob: 0.3, headBob: 0.2, frontLift: 1.1, rearLift: -0.9, tailLift: -0.2),
        RatPose(bodyBob: -0.5, headBob: -0.4, frontLift: -2.1, rearLift: 1.4, tailLift: 2.0),
        RatPose(bodyBob: 0.1, headBob: 0.2, frontLift: 0.7, rearLift: -1.6, tailLift: 0.1),
        RatPose(bodyBob: -0.2, headBob: -0.1, frontLift: -1.3, rearLift: 0.7, tailLift: 1.2),
    ]

    static func makeImage(frameIndex: Int) -> NSImage {
        let pose = poses[frameIndex % poses.count]
        let imageSize = NSSize(width: 36, height: 18)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        let color = NSColor.black
        color.setFill()
        color.setStroke()

        drawTail(pose: pose)
        drawBody(pose: pose)
        drawHead(pose: pose)
        drawLegs(pose: pose)
        drawWhiskers(pose: pose)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawBody(pose: RatPose) {
        let bodyRect = NSRect(x: 10, y: 4.5 + pose.bodyBob, width: 16, height: 8)
        NSBezierPath(roundedRect: bodyRect, xRadius: 5, yRadius: 5).fill()

        let haunchRect = NSRect(x: 7.5, y: 5.5 + pose.bodyBob, width: 7, height: 6)
        NSBezierPath(ovalIn: haunchRect).fill()
    }

    private static func drawHead(pose: RatPose) {
        let headRect = NSRect(x: 23, y: 6.2 + pose.headBob, width: 8.5, height: 6.5)
        NSBezierPath(ovalIn: headRect).fill()

        NSBezierPath(ovalIn: NSRect(x: 24.2, y: 11.3 + pose.headBob, width: 3.2, height: 3.2)).fill()
        NSBezierPath(ovalIn: NSRect(x: 26.8, y: 11.8 + pose.headBob, width: 2.8, height: 2.8)).fill()

        NSBezierPath(ovalIn: NSRect(x: 29.8, y: 8.7 + pose.headBob, width: 1.4, height: 1.4)).fill()
    }

    private static func drawTail(pose: RatPose) {
        let tail = NSBezierPath()
        tail.lineWidth = 1.8
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 8.5, y: 9))
        tail.curve(
            to: NSPoint(x: 1.2, y: 12.2 + pose.tailLift),
            controlPoint1: NSPoint(x: 5.0, y: 11.5 + pose.tailLift * 0.4),
            controlPoint2: NSPoint(x: 2.4, y: 12.8 + pose.tailLift)
        )
        tail.stroke()
    }

    private static func drawLegs(pose: RatPose) {
        drawLeg(from: NSPoint(x: 14.5, y: 4.8 + pose.bodyBob), hipOffset: 0.0, footLift: pose.rearLift)
        drawLeg(from: NSPoint(x: 24.0, y: 5.0 + pose.bodyBob), hipOffset: 0.4, footLift: pose.frontLift)
    }

    private static func drawLeg(from start: NSPoint, hipOffset: CGFloat, footLift: CGFloat) {
        let leg = NSBezierPath()
        leg.lineWidth = 2.0
        leg.lineCapStyle = .round
        leg.move(to: start)
        leg.line(to: NSPoint(x: start.x - 0.7 + hipOffset, y: start.y - 2.7))
        leg.line(to: NSPoint(x: start.x + 1.6 - hipOffset, y: start.y - 5.2 + footLift))
        leg.stroke()
    }

    private static func drawWhiskers(pose: RatPose) {
        let whiskers = NSBezierPath()
        whiskers.lineWidth = 0.9
        whiskers.lineCapStyle = .round

        let noseX: CGFloat = 30.6
        let noseY: CGFloat = 9.4 + pose.headBob
        whiskers.move(to: NSPoint(x: noseX, y: noseY))
        whiskers.line(to: NSPoint(x: 34.3, y: noseY + 1.3))
        whiskers.move(to: NSPoint(x: noseX, y: noseY - 0.2))
        whiskers.line(to: NSPoint(x: 34.6, y: noseY - 0.1))
        whiskers.move(to: NSPoint(x: noseX, y: noseY - 0.4))
        whiskers.line(to: NSPoint(x: 34.0, y: noseY - 1.5))
        whiskers.stroke()
    }
}
