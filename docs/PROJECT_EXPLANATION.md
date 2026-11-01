# Grupee — Project explanation

I built Grupee as a responsive product demo with a warm blue-and-brown design system, real-looking African property opportunities and a clear progression into co-ownership. The implementation separates public discovery from account dashboards and keeps sensitive integrations behind environment variables.

## Product reasoning

I chose a discovery-first experience so visitors understand the opportunity before creating an account. Pool cards expose the target, amount contributed and minimum investment; the detail screen adds a share calculator. The demo payment intentionally never takes money.

## Architecture and security

Vite powers the frontend, React Router provides navigation, and TypeScript defines product entities. A Supabase migration supplies the production database model with UUID keys, foreign keys, indexes, soft-delete fields, timestamps and row-level security. Real auth can sit on top of the existing protected route structure without exposing service credentials in the browser.

## AI use

I used AI to accelerate the initial product scaffolding and feature planning. The shipped Grupee Assistant interaction is a separate product capability with a server-side API pattern, factual pool context, friendly fallback behavior, rate-limit-ready design and a financial-advice disclaimer.

## Automation

The backend design supports welcome and recommendation emails, enquiry confirmations, join confirmations, in-app notifications, admin alerts and fully-funded status transitions through database triggers or API workflows.

## Accessibility and quality

The interface uses semantic elements, keyboard-operable controls, descriptive image alternatives, visible focus states, responsive layouts and reduced-motion-compatible CSS. Share calculations and auth behavior should be covered with targeted Vitest tests before production launch.

## Future improvements

The next phase should connect Supabase Auth, add Google Maps, connect a payment gateway, enable real email automation, complete server-side AI moderation and rate limiting, add KYC and transaction reconciliation, and replace demo analytics with live queries.
