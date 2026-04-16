# Product Requirements Document — Fixture App

## Overview

This PRD defines the requirements for the Fixture App, a minimal application
used as test input for the Cluster 5 parity test suite.

## Goals

- Provide a stable set of functional and non-functional requirements
- Enable deterministic output from planning skills

## Functional Requirements

### FR-001: User Login

**Description:** Users can log in with email and password.
**Acceptance Criteria:**
- Given valid credentials, user is authenticated and redirected to dashboard
- Given invalid credentials, an error message is displayed

### FR-002: Dashboard

**Description:** Display recent activity on the main dashboard.
**Acceptance Criteria:**
- Dashboard loads within 2 seconds
- Shows last 10 activity items

### FR-003: Settings

**Description:** Users can update their preferences.
**Acceptance Criteria:**
- User can change display name
- User can toggle notification preferences

## Non-Functional Requirements

### NFR-001: Performance

- Page load time under 2 seconds (p95)

### NFR-002: Accessibility

- WCAG 2.1 AA compliance on all pages

## User Journeys

### J1: First-time Login

1. User navigates to /login
2. Enters email and password
3. Clicks "Sign In"
4. Redirected to /dashboard

## Data Requirements

- User table: id, email, password_hash, display_name, created_at
- Activity table: id, user_id, action, timestamp

## Integrations

- OAuth 2.0 provider (optional)

## Success Criteria

- All FRs implemented and passing acceptance tests
- NFR-001 and NFR-002 verified in staging
