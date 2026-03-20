#!/usr/bin/env node
/**
 * 0dr1ft — ZeroDrift AI Gateway
 *
 * Entry point for the 0dr1ft rebrand of OpenClaw.
 * Loads 0dr1ft-specific config, then delegates to the upstream OpenClaw runtime.
 *
 * This file is intentionally thin: all business logic lives in src/ (upstream).
 * ZeroDrift customisations go in .env.0dr1ft (loaded here before OpenClaw reads env).
 *
 * Usage:
 *   node 0dr1ft.mjs          # direct
 *   pnpm 0dr1ft              # via package.json bin
 */

import { existsSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { config } from 'dotenv'

const __dirname = dirname(fileURLToPath(import.meta.url))

// Load 0dr1ft env overrides before OpenClaw initialises
const envFile = resolve(__dirname, '.env.0dr1ft')
if (existsSync(envFile)) {
  config({ path: envFile, override: false }) // don't override shell env vars
  console.log('[0dr1ft] Loaded .env.0dr1ft')
} else {
  console.warn('[0dr1ft] No .env.0dr1ft found — copy .env.0dr1ft.example to get started')
}

// Delegate to OpenClaw upstream entry point
await import('./openclaw.mjs')
