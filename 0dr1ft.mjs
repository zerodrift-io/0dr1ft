#!/usr/bin/env node

// 0dr1ft — ZeroDrift AI Automation Layer
// Wrapper around OpenClaw with ZeroDrift-specific defaults and branding.

import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { existsSync } from "node:fs";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Load 0dr1ft-specific environment defaults before OpenClaw starts.
// Precedence: process env > .env.0dr1ft > .env > OpenClaw defaults.
const odriftEnv = join(__dirname, ".env.0dr1ft");
if (existsSync(odriftEnv)) {
  const { config } = await import("dotenv");
  config({ path: odriftEnv, override: false });
}

// Delegate to OpenClaw entry point.
await import("./openclaw.mjs");
