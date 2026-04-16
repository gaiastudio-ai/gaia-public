# UX Design — Fixture App

## Design Principles

- Simplicity: minimal cognitive load
- Consistency: shared component library
- Accessibility: WCAG 2.1 AA compliance

## Information Architecture

```
/login
/dashboard
/settings
```

## Wireframes

### Login Page

- Email input field
- Password input field
- "Sign In" button (primary CTA)
- "Forgot password?" link

### Dashboard

- Header with app logo and user avatar
- Activity feed (card-based layout, 10 items)
- Sidebar navigation

### Settings

- Form with display name text input
- Toggle switches for notification preferences
- "Save" button (primary CTA)

## Interaction Patterns

- Form validation: inline error messages on blur
- Loading states: skeleton screens
- Navigation: persistent sidebar on desktop, hamburger on mobile

## Design Tokens

- Primary color: #2563EB
- Error color: #DC2626
- Font family: Inter, system-ui
- Border radius: 8px
- Spacing unit: 4px

## Accessibility Notes

- All form inputs have associated labels
- Color contrast ratio >= 4.5:1
- Keyboard navigation support on all interactive elements
- Screen reader announcements for dynamic content updates
