import { useLayoutEffect, useRef } from 'react'

import { SpacingOverlay, type Space } from './SpacingOverlay'

/** The landing page's named gaps, for the spacing overlay. */
const SPACES: Space[] = [
  { id: 'V1', label: 'Wordmark to brand promise', from: '.wordmark', fromEdge: 'bottom', to: '.tagline', toEdge: 'top' },
  { id: 'V2', label: 'Brand promise to project switcher', from: '.tagline', fromEdge: 'bottom', to: '.switcher', toEdge: 'top', span: '.stage' },
  { id: 'V3', label: 'Project switcher to the windows', from: '.switcher', fromEdge: 'bottom', to: '.stage', toEdge: 'top' },
  { id: 'V4', label: 'Windows to the benefits', from: '.stage', fromEdge: 'bottom', to: '.features', toEdge: 'top' },
  { id: 'V5', label: 'Benefit icon to its title', from: '.feature .mantine-ThemeIcon-root', fromEdge: 'bottom', to: '.feature h3', toEdge: 'top', span: '.feature' },
  { id: 'V6', label: 'Benefit title to its text', from: '.feature h3', fromEdge: 'bottom', to: '.feature p', toEdge: 'top', span: '.feature' },
  { id: 'H1', label: 'Benefit to benefit', from: '.feature:first-child', fromEdge: 'right', to: '.feature:nth-child(2)', toEdge: 'left' },
  { id: 'V7', label: 'Benefits to install title', from: '.features', fromEdge: 'bottom', to: '.install h3', toEdge: 'top', span: '.install__box' },
  { id: 'V8', label: 'Install title to the command', from: '.install h3', fromEdge: 'bottom', to: '.install__box', toEdge: 'top' },
  { id: 'V9', label: 'Command to the GitHub link', from: '.install__box', fromEdge: 'bottom', to: '.github', toEdge: 'top', span: '.install__box' },
]

/**
 * The spacing overlay on the landing page (the "Spacing" button, bottom right). Shown only while
 * developing (npm run dev), never in the built page.
 */
export function PageSpacing() {
  const root = useRef<HTMLElement | null>(null)
  // A layout effect runs before the overlay's own effects, so the root is set when it measures.
  useLayoutEffect(() => {
    root.current = document.querySelector<HTMLElement>('.page')
  }, [])
  return <SpacingOverlay root={root} spaces={SPACES} />
}
