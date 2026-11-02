//
//  FoldAvoiding.swift
//  Zili
//

import SwiftUI

extension View {
  /// Keeps the view off the fold of a partially folded iPhone Duo. While a fold the view can move
  /// away from crosses it, the view claims the room its container offers along `axes` and is laid
  /// out below a horizontal fold, on the half that lies flat in tabletop pose, or trailing a
  /// vertical one. Flat, closed, and on every other device, the view is laid out as it is.
  ///
  /// - Parameter axes: The directions the view may move in: horizontally to clear a vertical fold,
  ///   vertically to clear a horizontal one.
  func avoidingFold(movingAlong axes: Axis.Set = [.horizontal, .vertical]) -> some View {
    modifier(FoldAvoiding(axes: axes))
  }
}

extension CGRect {
  /// Whether a fold of this shape runs top to bottom.
  fileprivate var isVerticalFold: Bool { height > width }
}

private struct FoldAvoiding: ViewModifier {
  let axes: Axis.Set

  func body(content: Content) -> some View {
    #if os(iOS)
      if #available(iOS 27.1, *) {
        content.modifier(DivisionAvoiding(axes: axes))
      } else {
        content
      }
    #else
      content
    #endif
  }
}

#if os(iOS)
  @available(iOS 27.1, *)
  private struct DivisionAvoiding: ViewModifier {
    let axes: Axis.Set

    /// The active fold crossing the view, in the view's own coordinate space.
    @State private var fold: CGRect?

    nonisolated private static func fold(
      crossing geometry: GeometryProxy,
      movingAlong axes: Axis.Set
    ) -> CGRect? {
      let bounds = CGRect(origin: .zero, size: geometry.size)
      return geometry.reservedRegions(kind: .division).map(\.frame).first {
        $0.intersects(bounds) && axes.contains($0.isVerticalFold ? .horizontal : .vertical)
      }
    }

    func body(content: Content) -> some View {
      FoldClearLayout(fold: fold) { content }
        .onGeometryChange(for: CGRect?.self) { [axes] in
          Self.fold(crossing: $0, movingAlong: axes)
        } action: {
          fold = $0
        }
        // Ahead of any spacers beside it, so the view has the room to avoid the fold in.
        .layoutPriority(fold == nil ? 0 : 1)
    }
  }

  /// Lays out its content as it is, or, around a fold, fills the space it is offered across the
  /// fold and sets the content in the part the fold leaves clear. Along the fold it is as long as
  /// the content needs at the width or height it is placed at. Its size across the fold never
  /// depends on where the fold is, so moving the content can't move the fold.
  private struct FoldClearLayout: Layout {
    /// The fold to keep clear of, in the layout's own coordinate space.
    let fold: CGRect?

    /// The part of `bounds` below a horizontal `fold` or trailing a vertical one, unless the
    /// content fits there smaller than it would in the part before the fold.
    private static func clearRegion(
      of bounds: CGRect,
      avoiding fold: CGRect,
      for subview: LayoutSubview
    ) -> CGRect {
      let (after, before) =
        fold.isVerticalFold
        ? (
          bounds.divided(atDistance: bounds.maxX - fold.maxX, from: .maxXEdge).slice,
          bounds.divided(atDistance: fold.minX - bounds.minX, from: .minXEdge).slice
        )
        : (
          bounds.divided(atDistance: bounds.maxY - fold.maxY, from: .maxYEdge).slice,
          bounds.divided(atDistance: fold.minY - bounds.minY, from: .minYEdge).slice
        )
      let fitsAfter = subview.sizeThatFits(ProposedViewSize(after.size))
      let fitsBefore = subview.sizeThatFits(ProposedViewSize(before.size))
      return fitsAfter.width >= fitsBefore.width && fitsAfter.height >= fitsBefore.height
        ? after : before
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
      guard let subview = subviews.first else { return .zero }
      let fitted = subview.sizeThatFits(proposal)
      guard let fold else { return fitted }
      let bounds = CGRect(
        origin: .zero,
        size: CGSize(
          width: proposal.width ?? fitted.width,
          height: proposal.height ?? fitted.height
        )
      )
      let placed = subview.sizeThatFits(
        ProposedViewSize(Self.clearRegion(of: bounds, avoiding: fold, for: subview).size)
      )
      return fold.isVerticalFold
        ? CGSize(width: bounds.width, height: placed.height)
        : CGSize(width: placed.width, height: bounds.height)
    }

    func placeSubviews(
      in bounds: CGRect,
      proposal: ProposedViewSize,
      subviews: Subviews,
      cache _: inout ()
    ) {
      guard let subview = subviews.first else { return }
      guard let fold else {
        subview.place(at: bounds.origin, proposal: proposal)
        return
      }
      let region = Self.clearRegion(
        of: bounds,
        avoiding: fold.offsetBy(dx: bounds.minX, dy: bounds.minY),
        for: subview
      )
      subview.place(
        at: CGPoint(x: region.midX, y: region.midY),
        anchor: .center,
        proposal: ProposedViewSize(region.size)
      )
    }
  }
#endif
