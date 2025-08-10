import Foundation
import Vision
import CoreGraphics

struct PoseAnalysisResult {
    let frameNumber: Int
    let timestamp: TimeInterval
    let leftKneeAngle: Double?
    let rightKneeAngle: Double?
    let armRaised: Bool
    let confidence: Float
}

class PoseAnalyzer {
    private var poseResults: [PoseAnalysisResult] = []
    
    // Joint points needed for knee angle calculation
    private enum JointType {
        case leftHip, leftKnee, leftAnkle
        case rightHip, rightKnee, rightAnkle
        case rightWrist, rightElbow, rightShoulder
    }
    
    func processPoseObservation(_ observation: VNHumanBodyPoseObservation, frameNumber: Int, timestamp: TimeInterval) -> PoseAnalysisResult {
        // Calculate knee angles
        let leftKneeAngle = calculateLeftKneeAngle(from: observation)
        let rightKneeAngle = calculateRightKneeAngle(from: observation)
        
        // Check arm position
        let armRaised = checkArmRaised(from: observation)
        
        // Calculate overall confidence
        let confidence = calculateConfidence(from: observation)
        
        let result = PoseAnalysisResult(
            frameNumber: frameNumber,
            timestamp: timestamp,
            leftKneeAngle: leftKneeAngle,
            rightKneeAngle: rightKneeAngle,
            armRaised: armRaised,
            confidence: confidence
        )
        
        poseResults.append(result)
        return result
    }
    
    private func calculateLeftKneeAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
        do {
            let hip = try observation.recognizedPoint(.leftHip)
            let knee = try observation.recognizedPoint(.leftKnee)
            let ankle = try observation.recognizedPoint(.leftAnkle)
            
            // Check confidence
            guard hip.confidence > 0.3 && knee.confidence > 0.3 && ankle.confidence > 0.3 else {
                return nil
            }
            
            return calculateAngle(joint1: hip.location, joint2: knee.location, joint3: ankle.location)
        } catch {
            return nil
        }
    }
    
    private func calculateRightKneeAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
        do {
            let hip = try observation.recognizedPoint(.rightHip)
            let knee = try observation.recognizedPoint(.rightKnee)
            let ankle = try observation.recognizedPoint(.rightAnkle)
            
            // Check confidence
            guard hip.confidence > 0.3 && knee.confidence > 0.3 && ankle.confidence > 0.3 else {
                return nil
            }
            
            return calculateAngle(joint1: hip.location, joint2: knee.location, joint3: ankle.location)
        } catch {
            return nil
        }
    }
    
    private func checkArmRaised(from observation: VNHumanBodyPoseObservation) -> Bool {
        do {
            let wrist = try observation.recognizedPoint(.rightWrist)
            let elbow = try observation.recognizedPoint(.rightElbow)
            let shoulder = try observation.recognizedPoint(.rightShoulder)
            
            // Check if arm is raised (wrist higher than elbow and elbow higher than shoulder)
            // In Vision coordinates, Y=0 is top, Y=1 is bottom, so for arm raised: wrist.y < elbow.y < shoulder.y
            return wrist.y < elbow.y && elbow.y < shoulder.y && wrist.confidence > 0.3
        } catch {
            return false
        }
    }
    
    private func calculateConfidence(from observation: VNHumanBodyPoseObservation) -> Float {
        var totalConfidence: Float = 0
        var count: Float = 0
        
        // Check all major joints
        let jointsToCheck: [VNHumanBodyPoseObservation.JointName] = [
            .leftHip, .leftKnee, .leftAnkle,
            .rightHip, .rightKnee, .rightAnkle,
            .rightWrist, .rightElbow, .rightShoulder
        ]
        
        for joint in jointsToCheck {
            if let point = try? observation.recognizedPoint(joint) {
                totalConfidence += point.confidence
                count += 1
            }
        }
        
        return count > 0 ? totalConfidence / count : 0
    }
    
    private func calculateAngle(joint1: CGPoint, joint2: CGPoint, joint3: CGPoint) -> Double {
        // Calculate angle at joint2
        let vector1 = CGPoint(x: joint1.x - joint2.x, y: joint1.y - joint2.y)
        let vector2 = CGPoint(x: joint3.x - joint2.x, y: joint3.y - joint2.y)
        
        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0 }
        
        let cosineAngle = dotProduct / (magnitude1 * magnitude2)
        let angleRadians = acos(max(-1, min(1, cosineAngle))) // Clamp to valid range
        let angleDegrees = angleRadians * 180.0 / .pi
        
        return angleDegrees
    }
    
    func getAverageKneeAngles() -> (left: Double?, right: Double?) {
        let validLeftAngles = poseResults.compactMap { $0.leftKneeAngle }
        let validRightAngles = poseResults.compactMap { $0.rightKneeAngle }
        
        let leftAverage = validLeftAngles.isEmpty ? nil : validLeftAngles.reduce(0, +) / Double(validLeftAngles.count)
        let rightAverage = validRightAngles.isEmpty ? nil : validRightAngles.reduce(0, +) / Double(validRightAngles.count)
        
        return (leftAverage, rightAverage)
    }
    
    func getMinMaxKneeAngles() -> (leftMin: Double?, leftMax: Double?, rightMin: Double?, rightMax: Double?) {
        let validLeftAngles = poseResults.compactMap { $0.leftKneeAngle }
        let validRightAngles = poseResults.compactMap { $0.rightKneeAngle }
        
        return (
            validLeftAngles.min(),
            validLeftAngles.max(),
            validRightAngles.min(),
            validRightAngles.max()
        )
    }
    
    func reset() {
        poseResults.removeAll()
    }
    
    func formatKneeAngleResults() -> String {
        let (leftAvg, rightAvg) = getAverageKneeAngles()
        let (leftMin, leftMax, rightMin, rightMax) = getMinMaxKneeAngles()
        
        var results = "Kniewinkel-Analyse:\n\n"
        
        if let leftAvg = leftAvg, let leftMin = leftMin, let leftMax = leftMax {
            results += "Linkes Knie:\n"
            results += "  Durchschnitt: \(String(format: "%.1f", leftAvg))°\n"
            results += "  Bereich: \(String(format: "%.1f", leftMin))° - \(String(format: "%.1f", leftMax))°\n\n"
        }
        
        if let rightAvg = rightAvg, let rightMin = rightMin, let rightMax = rightMax {
            results += "Rechtes Knie:\n"
            results += "  Durchschnitt: \(String(format: "%.1f", rightAvg))°\n"
            results += "  Bereich: \(String(format: "%.1f", rightMin))° - \(String(format: "%.1f", rightMax))°\n"
        }
        
        if leftAvg == nil && rightAvg == nil {
            results += "Keine Kniewinkel erkannt. Stelle sicher, dass die Knie sichtbar sind."
        }
        
        return results
    }
}
