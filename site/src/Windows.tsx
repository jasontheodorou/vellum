import { useEffect, useRef, useState } from 'react'
import { SegmentedControl } from '@mantine/core'
import { useIntersection, useReducedMotion } from '@mantine/hooks'

type Project = {
  name: string
  shape: string
  colour: string
  port: number
  recap: string
  question: string
  answer: string
}

// Three projects, each in its own Vellum window with its own shape and port
const PROJECTS: Project[] = [
  {
    name: 'garden-planner', shape: '◆', colour: 'var(--v-blue)', port: 3001,
    recap: 'Last time, 16 Oct: chose raised beds, because the soil drains well. Next: confirm the bed sizes.',
    question: 'what did we decide about the paths?',
    answer: 'Gravel, on 12 Oct. It was cheaper than paving and drains better.',
  },
  {
    name: 'recipe-box', shape: '●', colour: 'var(--v-green)', port: 3002,
    recap: 'Last time, 17 Oct: added search by ingredient. Next: test it on a phone.',
    question: 'why did we drop the shopping list?',
    answer: 'On 9 Oct you said it was "too much for a first version". It is saved under decisions.',
  },
  {
    name: 'portfolio', shape: '▲', colour: 'var(--v-teal)', port: 3003,
    recap: 'Last time, 18 Oct: wrote the about page. Next: choose three case studies.',
    question: 'have I dealt with dark mode before?',
    answer: 'Yes, in recipe-box. The lesson: check both themes on a phone first.',
  },
]

// The lines Claude Code shows when you reopen a project, in order
function lines(p: Project) {
  return [
    { kind: 'cmd', text: `~/projects/${p.name} $ claude` },
    { kind: 'recap', text: p.recap },
    { kind: 'you', text: `> ${p.question}` },
    { kind: 'claude', text: p.answer },
  ]
}

// Pauses after each line: the command, the recap, the question, the answer
const PAUSES = [350, 900, 450, 0]

function Win({ project, slot, typing, run }: { project: Project; slot: number; typing: boolean; run: number }) {
  const reduce = useReducedMotion()
  const all = lines(project)
  // The first front window starts empty and waits for its turn to type
  const waiting = !typing && slot === 0 && run === 0 && !reduce
  const [shown, setShown] = useState(typing || waiting ? 0 : all.length)

  // Uncover the lines one after another each time this window starts typing
  useEffect(() => {
    if (waiting) return
    if (!typing || reduce) { setShown(all.length); return }
    setShown(0)
    const timers: number[] = []
    let at = 250
    all.forEach((l, i) => {
      timers.push(window.setTimeout(() => setShown(i + 1), at))
      at += Math.min(l.text.length * 16, 1300) + PAUSES[i]
    })
    return () => timers.forEach(clearTimeout)
  }, [typing, run, reduce, waiting])

  return (
    <article className="win" style={{ '--slot': slot, '--accent': project.colour } as React.CSSProperties} aria-hidden={slot !== 0}>
      <div className="win__bar">
        <span className="win__dots" aria-hidden="true" />
        <span className="win__title">{project.name}</span>
      </div>
      <div className="win__screen">
        {all.map((l, i) => (
          <p key={l.kind} className={`win__${l.kind}`}>
            <span
              className={i < shown ? 't typed' : 't'}
              style={{ '--steps': l.text.length, '--dur': `${Math.min(l.text.length * 16, 1300)}ms` } as React.CSSProperties}
            >
              {l.text}
            </span>
          </p>
        ))}
        <p className="win__status">
          <span className="win__shape">{project.shape}</span> <b>{project.name}</b>{'  '}
          <span className="win__live">live on :{project.port}</span>
        </p>
      </div>
    </article>
  )
}

export function Windows({ ready }: { ready: boolean }) {
  const [active, setActive] = useState(0)
  // Count each time a project is reopened, so its window types again
  const [opened, setOpened] = useState(0)
  const { ref, entry } = useIntersection({ threshold: 0.4 })
  const seen = useRef(false)
  if (entry?.isIntersecting) seen.current = true

  const order = [active, ...PROJECTS.map((_, i) => i).filter((i) => i !== active)]

  return (
    <section className="stage-wrap" aria-label="Three projects, each in its own Vellum window">
      <SegmentedControl
        className="switcher"
        value={String(active)}
        onChange={(v) => { setActive(Number(v)); setOpened((n) => n + 1) }}
        data={PROJECTS.map((p, i) => ({
          value: String(i),
          label: <span className="switcher__label"><span style={{ color: p.colour }}>{p.shape}</span> {p.name}</span>,
        }))}
        radius="xl"
        size="sm"
        aria-label="Reopen a project"
      />
      <div className="stage" ref={ref}>
        {PROJECTS.map((p, i) => (
          <Win key={p.name} project={p} slot={order.indexOf(i)} typing={i === active && seen.current && ready} run={i === active ? opened : -1} />
        ))}
      </div>
    </section>
  )
}
