//
//  FlipCardTests.swift
//  ZiliTests
//

import Testing
import SwiftUI

@testable import Zili

struct FlipCardTests {
  @Test(
    "Front face shows for the first quarter of a turn, the back face past it, wrapping every full turn"
  )
  func facePerAngle() {
    #expect(FlipCard<Text, Text>.showingBack(at: 0) == false)  // resting on the front
    #expect(FlipCard<Text, Text>.showingBack(at: 89) == false)  // still front, approaching edge-on
    #expect(FlipCard<Text, Text>.showingBack(at: 91) == true)  // just past edge-on, back showing
    #expect(FlipCard<Text, Text>.showingBack(at: 180) == true)  // resting on the back
    #expect(FlipCard<Text, Text>.showingBack(at: 271) == false)  // second half-turn shows front
    #expect(FlipCard<Text, Text>.showingBack(at: 360) == false)  // a full turn is the front again
  }
}
