import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { MantineProvider, createTheme, type MantineColorsTuple } from '@mantine/core'
import '@mantine/core/styles.css'
import './app.css'
import { App } from './App'

// Vellum's cobalt, from the logo and the cursor, at Mantine's shade 6
const cobalt: MantineColorsTuple = [
  '#eef2fc', '#dce3f8', '#b6c4f0', '#8ea3e7', '#6c87df',
  '#5674da', '#3455c5', '#2c47ae', '#253c93', '#1d3077',
]

const theme = createTheme({
  colors: { cobalt },
  primaryColor: 'cobalt',
  fontFamily: '"Geist", -apple-system, "Segoe UI", system-ui, sans-serif',
  fontFamilyMonospace: '"Geist Mono", ui-monospace, "SF Mono", Menlo, monospace',
  headings: { fontFamily: '"Geist", -apple-system, "Segoe UI", system-ui, sans-serif', fontWeight: '500' },
  defaultRadius: 'md',
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <MantineProvider theme={theme} forceColorScheme="light">
      <App />
    </MantineProvider>
  </StrictMode>,
)
