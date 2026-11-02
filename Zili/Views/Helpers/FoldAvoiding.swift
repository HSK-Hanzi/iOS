//
//  FoldAvoiding.swift
//  Zili
//

import SwiftUI

extension View {
  /// Keeps the view off the fold of a partially folded iPhone Duo. While a fold crosses the view,
  /// the view claims all the space its container offers and is laid out below a horizontal fold,
  /// on the half that lies flat in tabletop pose, or trailing a vertical one. Flat, closed, and on
  /// every other device, the view is laid out as it is.
  func avoidingFold() -> some View {
    modifier(FoldAvoiding())
  }
}

private struct FoldAvoiding: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      if #available(iOS 27.1, *) {
        content.modifier(DivisionAvoiding())
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
    /// The active fold crossing the view, in the view's own coordinate space.
    @State private var fold: CGRect?

    nonisolated private static func fold(crossing geometry: GeometryProxy) -> CGRect? {
      let bounds = CGRect(origin: .zero, size: geometry.size)
      return geometry.reservedRegions(kind: .division).map(\.frame).first { $0.intersects(bounds) }
    }

    func body(content: Content) -> some View {
      FoldClearLayout(fold: fold) { content }
        .onGeometryChange(for: CGRect?.self, of: Self.fold(crossing:)) { fold = $0 }
        // Ahead of any spacers beside it, so the view has the room to avoid the fold in.
        .layoutPriority(fold == nil ? 0 : 1)
    }
  }

  /// Lays out its content as it is, or, around a fold, fills the space it is offered and sets the
  /// content in the part the fold leaves clear. Its own size never depends on where the fold is,
  /// so moving the content can't move the fold.
  private struct FoldClearLayout: Layout {
    /// The fold to keep clear of, in the layout's own coordinate space.
    let fold: CGRect?

    /// The part of `bounds` below a horizontal `fold` or trailing a vertical one, or the part
    /// before it when the fold leaves no room after.
    private static func clearRegion(of bounds: CGRect, avoiding fold: CGRect) -> CGRect {
      let (after, before) =
        fold.height > fold.width
        ? (
          bounds.divided(atDistance: bounds.maxX - fold.maxX, from: .maxXEdge).slice,
          bounds.divided(atDistance: fold.minX - bounds.minX, from: .minXEdge).slice
        )
        : (
          bounds.divided(atDistance: bounds.maxY - fold.maxY, from: .maxYEdge).slice,
          bounds.divided(atDistance: fold.minY - bounds.minY, from: .minYEdge).slice
        )
      return after.isEmpty ? before : after
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
      let fitted = subviews.first?.sizeThatFits(proposal) ?? .zero
      guard fold != nil else { return fitted }
      return CGSize(width: proposal.width ?? fitted.width, height: proposal.height ?? fitted.height)
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
        avoiding: fold.offsetBy(dx: bounds.minX, dy: bounds.minY)
      )
      subview.place(
        at: CGPoint(x: region.midX, y: region.midY),
        anchor: .center,
        proposal: ProposedViewSize(region.size)
      )
    }
  }
#endif
