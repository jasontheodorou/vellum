import { useEffect, useState } from 'react'
import { useReducedMotion } from '@mantine/hooks'

const PROMISE = 'A terminal window that works with you, not against you.'

// The brand promise types itself out once, then the cursor stops at the end.
// The untyped rest stays in place but unseen, so the lines never reflow.
export function BrandPromise({ onDone }: { onDone?: () => void }) {
  const reduce = useReducedMotion()
  const [count, setCount] = useState(0)
  const done = reduce || count >= PROMISE.length

  useEffect(() => {
    if (reduce) return
    let n = 0
    const start = window.setTimeout(function tick() {
      n += 1
      setCount(n)
      if (n < PROMISE.length) timer = window.setTimeout(tick, 38)
    }, 500)
    let timer = start
    return () => clearTimeout(timer)
  }, [reduce])

  useEffect(() => { if (done) onDone?.() }, [done])

  const shown = done ? PROMISE.length : count
  return (
    <p className="tagline" aria-label={PROMISE}>
      <span aria-hidden="true">{PROMISE.slice(0, shown)}</span>
      <span className={done ? 'cursor cursor--rest' : 'cursor'} aria-hidden="true" />
      <span className="tagline__rest" aria-hidden="true">{PROMISE.slice(shown)}</span>
    </p>
  )
}
