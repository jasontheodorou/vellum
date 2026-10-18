import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Relative paths, so the built page works from any folder or GitHub Pages
export default defineConfig({ plugins: [react()], base: './' })
