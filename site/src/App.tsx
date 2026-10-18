import {
  ActionIcon, Anchor, Badge, Code, Container, CopyButton, Group, SimpleGrid,
  Stack, Text, ThemeIcon, Title, Tooltip,
} from '@mantine/core'
import { IconBrandGithub, IconCheck, IconCopy, IconEye, IconNotebook, IconSquares } from '@tabler/icons-react'
import { Windows } from './Windows'

const INSTALL = 'curl -fsSL https://raw.githubusercontent.com/jasontheodorou/vellum/main/install.sh | bash'

const LOGO = `██╗   ██╗███████╗██╗     ██╗     ██╗   ██╗███╗   ███╗
██║   ██║██╔════╝██║     ██║     ██║   ██║████╗ ████║
██║   ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║
╚██╗ ██╔╝██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║
 ╚████╔╝ ███████╗███████╗███████╗╚██████╔╝██║ ╚═╝ ██║
  ╚═══╝  ╚══════╝╚══════╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝`

const FEATURES = [
  {
    icon: IconEye,
    title: 'Easy on the eyes',
    text: 'Soft lemon paper, dark ink and Paper Mono. Every colour Claude uses is readable on the page.',
  },
  {
    icon: IconNotebook,
    title: 'Remembers for you',
    text: 'An always-on journal of what you decided and why, with a short recap each time you come back.',
  },
  {
    icon: IconSquares,
    title: 'Keeps projects apart',
    text: 'Each window gets its own shape, and each project its own localhost port.',
  },
]

export function App() {
  return (
    <Container size="lg" className="page">
      <h1 className="logo">
        <span className="visually-hidden">Vellum</span>
        <pre aria-hidden="true">{LOGO}</pre>
      </h1>

      <Windows />

      <Stack gap="md" mt={88} maw={720}>
        <Badge variant="light" color="cobalt" radius="sm" size="lg" tt="none" fw={500} w="fit-content">
          For the macOS Terminal and Claude Code
        </Badge>
        <Title order={2} className="tagline">
          A terminal window that works with you, not against&nbsp;you.<span className="cursor" aria-hidden="true" />
        </Title>
      </Stack>

      <SimpleGrid cols={{ base: 1, sm: 3 }} spacing={40} verticalSpacing={32} mt={56}>
        {FEATURES.map((f) => (
          <Stack key={f.title} gap={12}>
            <ThemeIcon variant="light" color="cobalt" size={40} radius="md">
              <f.icon size={22} stroke={1.6} />
            </ThemeIcon>
            <Text fw={600} size="lg">{f.title}</Text>
            <Text c="gray.7" size="md" lh={1.55}>{f.text}</Text>
          </Stack>
        ))}
      </SimpleGrid>

      <Stack gap="sm" mt={72}>
        <Text fw={600} size="sm">Install on a Mac with Claude Code</Text>
        <Group className="install" wrap="nowrap" gap="sm">
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
        <Anchor href="https://github.com/jasontheodorou/vellum" c="dark" size="sm" mt="sm" w="fit-content" className="github">
          <IconBrandGithub size={16} /> Vellum on GitHub
        </Anchor>
      </Stack>
    </Container>
  )
}
