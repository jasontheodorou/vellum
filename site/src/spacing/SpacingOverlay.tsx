// Ported from katsura's spacing overlay (foundations/[chapter]/components).

import { useEffect, useState, type RefObject } from 'react'

import './spacing-overlay.css'

/**
 * A temporary design aid: draws every named gap on the page as a dashed box with its ID and its
 * measured size to a tenth of a pixel, so spacing can be discussed by ID ("tighten V3"). It
 * measures what the eye sees: text from cap height to baseline, everything else by its painted
 * edge. Remove from a page once its spacing is settled.
 */

type Edge = 'top' | 'bottom' | 'left' | 'right'

export type Space = {
  id: string
  /** What the gap separates, shown on hover. */
  label: string
  from: string
  fromEdge: Edge
  to: string
  toEdge: Edge
  /** Selector whose extent gives the box its length along the other axis. */
  span?: string
}

type Box = {
  id: string
  label: string
  x: number
  y: number
  w: number
  h: number
  size: number
  axis: 'v' | 'h'
  /** What each end was measured to, for the tooltip. */
  how: string
}

type Edges = { top: number; bottom: number; left: number; right: number; how: string }

/** True when an element paints something of its own: an image, a fill, a border or a shadow. */
function paints(n: HTMLElement): boolean {
  if (n instanceof HTMLImageElement || n instanceof SVGElement || n.tagName === 'VIDEO') return true
  const cs = getComputedStyle(n)
  const bg = cs.backgroundColor
  const hasBg = bg !== 'transparent' && !/rgba\(.*,\s*0\)$/.test(bg)
  const hasBorder = ['Top', 'Right', 'Bottom', 'Left'].some(
    (k) => parseFloat(cs.getPropertyValue(`border-${k.toLowerCase()}-width`)) > 0,
  )
  return hasBg || hasBorder || cs.boxShadow !== 'none' || cs.backgroundImage !== 'none'
}

/**
 * What the eye sees of an element, in the overlay's coordinates. Anything that paints (image,
 * fill, border, shadow) is measured by its box. Text is measured from the top of the capital
 * letters on its first line to the baseline of its last line, using the font's own metrics, so
 * line-height and leading never count as space.
 */
function visibleBox(
  n: HTMLElement,
  ctx: CanvasRenderingContext2D | null,
  ox: number,
  oy: number,
): Edges {
  const r = n.getBoundingClientRect()
  const box = { top: r.top + oy, bottom: r.bottom + oy, left: r.left + ox, right: r.right + ox }
  // Containers (anything with a block-level child) are measured by their box, not their text.
  const container = [...n.children].some((c) => !getComputedStyle(c).display.startsWith('inline'))
  if (paints(n) || container || !ctx) return { ...box, how: 'edge' }
  // Only real text counts: decorative inline boxes (such as the title's full stop) are skipped.
  const lines: DOMRect[] = []
  const walker = document.createTreeWalker(n, NodeFilter.SHOW_TEXT)
  for (let t = walker.nextNode(); t; t = walker.nextNode()) {
    if (!t.textContent?.trim()) continue
    const range = document.createRange()
    range.selectNodeContents(t)
    lines.push(...[...range.getClientRects()].filter((q) => q.width > 0 && q.height > 0))
  }
  if (!lines.length) return { ...box, how: 'edge' }
  const cs = getComputedStyle(n)
  ctx.font = `${cs.fontStyle} ${cs.fontWeight} ${cs.fontSize} ${cs.fontFamily}`
  const ascent = ctx.measureText('Hg').fontBoundingBoxAscent
  const cap = ctx.measureText('H').actualBoundingBoxAscent
  const first = lines.reduce((m, q) => (q.top < m.top ? q : m))
  const last = lines.reduce((m, q) => (q.top > m.top ? q : m))
  return {
    ...box,
    top: first.top + oy + ascent - cap,
    bottom: last.top + oy + ascent,
    how: 'text',
  }
}

type OverlayProps = {
  root: RefObject<HTMLElement | null>
  spaces: Space[]
}

/** A design tool only: it never ships in a production build, so readers never see it. */
export function SpacingOverlay(props: OverlayProps) {
  if (import.meta.env.PROD) return null
  return <Overlay {...props} />
}

function Overlay({ root, spaces }: OverlayProps) {
  const [boxes, setBoxes] = useState<Box[]>([])
  const [on, setOn] = useState(true)

  // Remember the choice on this device, so the overlay stays off once switched off.
  useEffect(() => {
    try {
      if (localStorage.getItem('vellum:spacing') === 'off') setOn(false)
    } catch {
      // Storage unavailable: keep the default.
    }
  }, [])

  const toggle = () => {
    setOn((v) => {
      try {
        localStorage.setItem('vellum:spacing', v ? 'off' : 'on')
      } catch {
        // Storage unavailable: the toggle still works for this visit.
      }
      return !v
    })
  }

  useEffect(() => {
    const el = root.current
    if (!el) return
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')

    const measure = () => {
      const base = el.getBoundingClientRect()
      const oy = el.scrollTop - base.top
      const ox = -base.left
      const find = (s: string) => {
        // Inside the root first; then anywhere on the page, for a gap that starts outside it (such
        // as the top bar above the home page).
        const n = el.querySelector<HTMLElement>(s) ?? document.querySelector<HTMLElement>(s)
        return n ? visibleBox(n, ctx, ox, oy) : null
      }
      const out: Box[] = []
      for (const s of spaces) {
        const a = find(s.from)
        const b = find(s.to)
        const span = find(s.span ?? s.to)
        if (!a || !b || !span) continue
        const vertical = s.fromEdge === 'top' || s.fromEdge === 'bottom'
        const e1 = a[s.fromEdge]
        const e2 = b[s.toEdge]
        const size = Math.round(Math.abs(e2 - e1) * 10) / 10
        out.push(
          vertical
            ? {
                id: s.id,
                label: s.label,
                axis: 'v',
                x: span.left,
                w: span.right - span.left,
                y: Math.min(e1, e2),
                h: Math.abs(e2 - e1),
                size,
                how: `${a.how} to ${b.how}`,
              }
            : {
                id: s.id,
                label: s.label,
                axis: 'h',
                y: span.top,
                h: span.bottom - span.top,
                x: Math.min(e1, e2),
                w: Math.abs(e2 - e1),
                size,
                how: `${a.how} to ${b.how}`,
              },
        )
      }
      setBoxes(out)
    }

    measure()
    const ro = new ResizeObserver(measure)
    ro.observe(el)
    el.querySelectorAll('*').forEach((n) => ro.observe(n))
    void document.fonts?.ready.then(measure)
    // Opening and closing sections, and animations settling, change the layout: measure again.
    const later = () => window.setTimeout(measure, 350)
    el.addEventListener('toggle', later, true)
    el.addEventListener('transitionend', later, true)
    const t = window.setTimeout(measure, 1200)
    return () => {
      ro.disconnect()
      el.removeEventListener('toggle', later, true)
      el.removeEventListener('transitionend', later, true)
      window.clearTimeout(t)
    }
  }, [root, spaces])

  return (
    <>
      <button type="button" className="spacing-overlay__toggle" aria-pressed={on} onClick={toggle}>
        Spacing
      </button>
      {on && (
        <div className="spacing-overlay" aria-hidden="true">
          {boxes.map((b) => (
            <div
              key={b.id}
              className={`spacing-overlay__box spacing-overlay__box--${b.axis}`}
              style={{ left: b.x, top: b.y, width: b.w, height: b.h }}
              title={`${b.id}: ${b.label}, ${b.size}px`}
            >
              <span className="spacing-overlay__tag">
                {b.id} · {b.size}px
              </span>
            </div>
          ))}
        </div>
      )}
    </>
  )
}
