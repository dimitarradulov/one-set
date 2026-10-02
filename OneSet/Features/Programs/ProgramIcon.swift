import SwiftUI

/// Program identity artwork drawn on a 32-point canvas, independent of selection tint.
struct ProgramIcon: Shape {
  let programID: TrainingProgram.ID

  func path(in rect: CGRect) -> Path {
    var path = Path()

    switch programID {
    case "upper-lower":
      addStandingFigure(to: &path)
      path = path.applying(CGAffineTransform(translationX: -4, y: 0))
      addLines([(27, 6), (27, 26)], to: &path)
      addLines([(24, 9), (27, 6), (30, 9)], to: &path)
      addLines([(24, 23), (27, 26), (30, 23)], to: &path)

    case "push-pull-legs":
      addStandingFigure(to: &path)
      addLines([(2, 13), (7, 13)], to: &path)
      addLines([(4, 10), (1, 13), (4, 16)], to: &path)
      addLines([(25, 13), (30, 13)], to: &path)
      addLines([(28, 10), (31, 13), (28, 16)], to: &path)

    case "bro-split":
      addStandingFigure(to: &path)
      addLines([(5, 6), (7, 8)], to: &path)
      addLines([(25, 8), (27, 6)], to: &path)
      addLines([(2, 18), (5, 18)], to: &path)
      addLines([(27, 18), (30, 18)], to: &path)
      addLines([(15, 31), (17, 31)], to: &path)

    case "minimalist-full-body":
      addHead(to: &path)
      // A compact hands-on-hips stance keeps an athletic body with economical detail.
      addLines([
        (12, 9), (8, 10), (5, 16), (10, 20), (10, 29), (14, 29),
        (16, 23), (18, 29), (22, 29), (22, 20), (27, 16), (24, 10),
        (20, 9), (12, 9)
      ], to: &path)
      path.closeSubpath()
      addLines([(9, 14), (8, 16), (12, 19)], to: &path)
      addLines([(23, 14), (24, 16), (20, 19)], to: &path)

    case "v-taper":
      // A cropped back contour emphasizes shoulder and lat width, not waist reduction.
      path.move(to: CGPoint(x: 12, y: 5))
      path.addQuadCurve(to: CGPoint(x: 3, y: 9), control: CGPoint(x: 6, y: 5))
      path.addQuadCurve(to: CGPoint(x: 9, y: 21), control: CGPoint(x: 4, y: 16))
      path.addQuadCurve(to: CGPoint(x: 12, y: 28), control: CGPoint(x: 12, y: 25))
      path.addLine(to: CGPoint(x: 20, y: 28))
      path.addQuadCurve(to: CGPoint(x: 23, y: 21), control: CGPoint(x: 20, y: 25))
      path.addQuadCurve(to: CGPoint(x: 29, y: 9), control: CGPoint(x: 28, y: 16))
      path.addQuadCurve(to: CGPoint(x: 20, y: 5), control: CGPoint(x: 26, y: 5))
      path.addQuadCurve(to: CGPoint(x: 12, y: 5), control: CGPoint(x: 16, y: 9))
      path.closeSubpath()
      addLines([(9, 12), (12, 18)], to: &path)
      addLines([(23, 12), (20, 18)], to: &path)

    case "powerhouse":
      addHead(to: &path)
      // Broad torso, thick arms and a planted lower body carry the density cue together.
      addLines([
        (12, 9), (7, 10), (4, 18), (7, 20), (10, 15), (10, 21),
        (7, 29), (12, 29), (16, 23), (20, 29), (25, 29), (22, 21),
        (22, 15), (25, 20), (28, 18), (25, 10), (20, 9), (12, 9)
      ], to: &path)
      path.closeSubpath()
      addLines([(12, 14), (16, 16), (20, 14)], to: &path)

    case "classic-physique":
      addHead(to: &path)
      // A symmetrical double-biceps pose includes the legs to distinguish it from V-Taper.
      addLines([
        (13, 9), (10, 11), (7, 11), (6, 5), (3, 6), (3, 14),
        (10, 16), (12, 14), (13, 20), (11, 29), (14, 29), (16, 23),
        (18, 29), (21, 29), (19, 20), (20, 14), (22, 16), (29, 14),
        (29, 6), (26, 5), (25, 11), (22, 11), (19, 9), (13, 9)
      ], to: &path)
      path.closeSubpath()

    case "free-weight-full-body":
      addLines([(2, 16), (30, 16)], to: &path)
      path.addRoundedRect(
        in: CGRect(x: 5, y: 7, width: 4, height: 18),
        cornerSize: CGSize(width: 1, height: 1)
      )
      path.addRoundedRect(
        in: CGRect(x: 23, y: 7, width: 4, height: 18),
        cornerSize: CGSize(width: 1, height: 1)
      )
      addLines([(2, 12), (2, 20)], to: &path)
      addLines([(30, 12), (30, 20)], to: &path)

    case "machine-full-body":
      addLines([(5, 3), (5, 29), (27, 29), (27, 3)], to: &path)
      addLines([(12, 3), (12, 6)], to: &path)
      addLines([(20, 3), (20, 6)], to: &path)
      path.addRoundedRect(
        in: CGRect(x: 9, y: 6, width: 14, height: 19),
        cornerSize: CGSize(width: 1.5, height: 1.5)
      )
      addLines([(9, 11), (23, 11)], to: &path)
      addLines([(9, 16), (23, 16)], to: &path)
      addLines([(9, 21), (23, 21)], to: &path)
      addLines([(18, 18.5), (25, 18.5)], to: &path)
      path.addEllipse(in: CGRect(x: 24, y: 17, width: 3, height: 3))

    default:
      // Full Body is also the neutral identity for an uncatalogued program.
      addStandingFigure(to: &path)
    }

    let scale = min(rect.width, rect.height) / 32
    return path.applying(CGAffineTransform(
      a: scale, b: 0, c: 0, d: scale,
      tx: rect.midX - 16 * scale,
      ty: rect.midY - 16 * scale
    ))
  }

  private func addStandingFigure(to path: inout Path) {
    addHead(to: &path)
    addLines([
      (13, 9), (10, 10), (8, 18), (10, 19), (12, 14), (12, 20),
      (10, 29), (13, 29), (16, 22), (19, 29), (22, 29), (20, 20),
      (20, 14), (22, 19), (24, 18), (22, 10), (19, 9), (13, 9)
    ], to: &path)
    path.closeSubpath()
  }

  private func addHead(to path: inout Path) {
    path.addEllipse(in: CGRect(x: 13.5, y: 1.5, width: 5, height: 5))
  }

  private func addLines(_ points: [(CGFloat, CGFloat)], to path: inout Path) {
    guard let first = points.first else { return }
    path.move(to: CGPoint(x: first.0, y: first.1))
    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: point.0, y: point.1))
    }
  }
}
