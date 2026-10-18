import {
  ActionIcon, Anchor, Code, Container, CopyButton, Group, SimpleGrid, ThemeIcon, Tooltip,
} from '@mantine/core'
import { IconBrandGithub, IconCheck, IconCopy, IconEye, IconNotebook, IconSquares } from '@tabler/icons-react'
import { useState } from 'react'
import { Windows } from './Windows'
import { BrandPromise } from './BrandPromise'

const INSTALL = 'curl -fsSL https://raw.githubusercontent.com/jasontheodorou/vellum/main/install.sh | bash'

// The banner drawn in light shade, so it reads as print on paper, not a solid block
const LOGO = `██╗   ██╗███████╗██╗     ██╗     ██╗   ██╗███╗   ███╗
██║   ██║██╔════╝██║     ██║     ██║   ██║████╗ ████║
██║   ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║
╚██╗ ██╔╝██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║
 ╚████╔╝ ███████╗███████╗███████╗╚██████╔╝██║ ╚═╝ ██║
  ╚═══╝  ╚══════╝╚══════╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝`.replace(/█/g, '░')

const FEATURES = [
  {
    icon: IconEye,
    title: 'Easy on the eyes',
    text: 'Soft paper, dark ink, and colours you can always read.',
  },
  {
    icon: IconNotebook,
    title: 'Remembers for you',
    text: 'A journal of every decision, and a recap when you return.',
  },
  {
    icon: IconSquares,
    title: 'Keeps projects apart',
    text: 'Every project gets its own shape and its own port.',
  },
]

export function App() {
  // The windows start typing once the brand promise is written
  const [ready, setReady] = useState(false)
  return (
    <Container size="lg" className="page">
      <header>
        <h1 className="logo">
          <span className="visually-hidden">Vellum</span>
          <pre aria-hidden="true">{LOGO}</pre>
        </h1>
        <BrandPromise onDone={() => setReady(true)} />
      </header>

      <Windows ready={ready} />

      <SimpleGrid cols={{ base: 1, sm: 3 }} spacing={48} verticalSpacing={48}>
        {FEATURES.map((f) => (
          <div key={f.title} className="feature">
            <ThemeIcon variant="light" color="cobalt" size={48} radius="md">
              <f.icon size={26} stroke={1.6} />
            </ThemeIcon>
            <h3>{f.title}</h3>
            <p>{f.text}</p>
          </div>
        ))}
      </SimpleGrid>

      <div className="install">
        <h3>Install on a Mac with Claude Code</h3>
        <Group className="install__box" wrap="nowrap" gap="sm">
          <Code className="install__code">{INSTALL}</Code>
          <CopyButton value={INSTALL} timeout={2000}>
            {({ copied, copy }) => (
              <Tooltip label={copied ? 'Copied' : 'Copy'} withArrow position="top">
                <ActionIcon variant="default" size="lg" onClick={copy} aria-label="Copy the install command">
                  {copied ? <IconCheck size={18} /> : <IconCopy size={18} />}
                </ActionIcon>
              </Tooltip>
            )}
          </CopyButton>
        </Group>
        <Anchor href="https://github.com/jasontheodorou/vellum" c="dark" className="github">
          <IconBrandGithub size={18} /> Vellum on GitHub
        </Anchor>
      </div>
    </Container>
  )
}
