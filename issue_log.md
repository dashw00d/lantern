# Lantern UI Refactor — Issue Log

Issues spotted during implementation that weren't in the original audit.

---

## Found during Phase 0 quick-fixes

1. **Settings.tsx: No error feedback on save failure** — `handleSave` has `try/finally` but no `catch`. If `update()` throws, the user gets no error toast. Should add a `catch` with `addToast({ type: 'error', message: 'Failed to save settings' })`.

2. **ProjectDetail.tsx HealthTab: Silent catch in handleCheck** — The `handleCheck` async function (around line 1191) has `catch { // ignore }` with no logging or user feedback when the health check request fails.

3. **Projects.tsx: Silent error in loadTools** — When `api.listTools` fails (lines 154-157), it silently sets `availableTools` to `[]` without a console warning. Could confuse debugging.

## Found during Phase 1 primitives

4. **Missing tailwindcss-animate plugin** — `Toast.tsx` uses `animate-in slide-in-from-right-5 fade-in` classes and `Modal.tsx` uses `animate-in zoom-in-95 fade-in`, but `tailwindcss-animate` is not installed as a dependency or registered as a plugin in `tailwind.config.js`. These animation classes are silently ignored. Should install `tailwindcss-animate` and add it to the plugins array.

## Found during Phase 5 adoption

5. **OverviewTab.tsx: Copy button has no primitive** — The Copy button next to the domain in OverviewTab uses a bare `<button>` with minimal styling (`text-muted-foreground hover:text-foreground`). It works but is not wrapped in `<Button>` — intentionally left since it's inline within a `<dd>` text flow and `Button` would add unwanted height/padding.

6. **ProjectDetail.tsx: Tab buttons are raw `<button>` elements** — The tab strip uses raw `<button>` elements with custom border-b styling for the active tab underline. These are intentionally NOT using `<Button>` because the tab navigation pattern doesn't match any Button variant — it needs the bottom-border active indicator, not bg-based highlighting. A dedicated `TabButton` or `Tabs` primitive would be appropriate for Phase 6 or 7.

7. **ProjectCard.tsx: External link anchor not wrapped** — The "Open in browser" `<a>` in ProjectCard uses raw Tailwind classes matching the ghost icon pattern. Can't use `<Button>` since it renders a `<button>`, not an `<a>`. Consider adding an `asChild` pattern or a link variant to Button in the future.

## Found during Phase 6 accessibility pass

8. **RunTab.tsx: Environment variables section is read-only with no edit UI** — The environment variables listed in RunTab are display-only (`project.run_env`). There's no way to add/edit/remove env vars from the UI. This is a feature gap, not a bug.

9. **DocsTab.tsx: Document list buttons lack descriptive aria-labels** — The doc buttons in the sidebar list use `doc.path` as visible text, which is adequate for sighted users, but the button's accessible name could be more descriptive (e.g., "View document: README.md").

10. **ProjectCard/Dashboard: "Open in browser" links lack aria-label** — The `<a>` elements styled as icon buttons for opening projects in the browser have `title="Open in browser"` but no `aria-label`. Since they're `<a>` elements (not `<Button>`), the `aria-label` should be added directly. These are not caught by searching for `size="icon"` since they're raw anchor tags.

