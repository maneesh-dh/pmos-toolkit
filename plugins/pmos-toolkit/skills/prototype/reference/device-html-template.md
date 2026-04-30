# Per-Device HTML Template

Each `index.<device>.html` follows this structure. Generated once per device by the Phase 5 subagent.

## Skeleton

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{Feature Name} — {Device Label} Prototype</title>
  <meta name="mock-entities" content="users,products,orders">

  <link rel="stylesheet" href="./assets/prototype.css">
  <link rel="stylesheet" href="./assets/styles.css">

  <script src="https://unpkg.com/react@18/umd/react.development.js"></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
  <script src="./assets/runtime.js"></script>
  <script type="text/babel" src="./assets/components.js" data-presets="react"></script>
</head>
<body class="device-{device}">
  <div id="root"></div>

  <!-- inline-data fallback for file:// portability -->
  <script type="application/json" id="mock-users">[…verbatim JSON…]</script>
  <script type="application/json" id="mock-products">[…verbatim JSON…]</script>
  <script type="application/json" id="mock-orders">[…verbatim JSON…]</script>

  <!-- screen components -->
  <script type="text/babel" data-presets="react">
    const { Button, Input, Modal, Toast, Card, Table, EmptyState, Spinner, Badge, Avatar } = window.__protoComponents;
    const { useRoute, navigate, mockApi, store, useStore } = window.__proto;

    function DashboardScreen() {
      const orders = useStore('orders');
      const [loading, setLoading] = React.useState(true);
      React.useEffect(() => { window.__proto.ready.then(() => setLoading(false)); }, []);
      if (loading) return <Spinner size="lg" />;
      return (
        <div className="screen screen--dashboard">
          <h1>Dashboard</h1>
          {/* … */}
        </div>
      );
    }
    // … one screen component per wireframe screen

    window.__screens = { DashboardScreen, /* … */ };
  </script>

  <!-- app shell: device frame + router outlet + global modals -->
  <script type="text/babel" data-presets="react">
    const { useRoute } = window.__proto;
    const screens = window.__screens;

    function App() {
      const { path } = useRoute();
      // route → screen lookup
      const Screen = resolveScreen(path) || NotFoundScreen;
      return (
        <div className="app-frame">
          <DeviceChrome />
          <main className="app-content"><Screen /></main>
          <GlobalToasts />
        </div>
      );
    }

    function resolveScreen(path) {
      if (path === '/' || path === '/dashboard') return screens.DashboardScreen;
      if (path.startsWith('/users/')) return screens.UserDetailScreen;
      if (path === '/users') return screens.UsersListScreen;
      // …
      return null;
    }

    function DeviceChrome() {
      // device-specific outer frame; rules below
      return null; // desktop-web: no chrome
    }

    function NotFoundScreen() {
      return <EmptyState title="Screen not found" description="This route is not part of the prototype." cta={<Button onClick={() => navigate('/')}>Back to start</Button>} />;
    }

    function GlobalToasts() {
      // subscribe to a toast queue if present; render stacked toasts
      return null;
    }

    ReactDOM.createRoot(document.getElementById('root')).render(<App />);
  </script>
</body>
</html>
```

## Device chrome rules

| Device | Frame | Chrome elements |
|--------|-------|-----------------|
| desktop-web | 1280×800 viewport hint | None (full-bleed app shell) |
| mobile-web | 375×812 rounded | Browser address bar mock at top, home indicator at bottom |
| ios-app | 375×812 rounded, status bar | iOS status bar (time, signal, battery), bottom tab bar (if app uses tabs), large title pattern, sheet presentation for modals |
| android-app | 360×800 | Android status bar, bottom nav (if used), FAB (if primary create action), system back gesture hint |
| desktop-app | 1280×800 with window chrome | macOS-style traffic lights (close/min/max), title bar |

CSS for these lives in `prototype.css` keyed off `body.device-<name>`. Subagent does NOT add inline styles — uses the classes.

## Strict rules for the generator subagent

1. **Load order is fixed.** Don't move `runtime.js` after Babel scripts.
2. **Inline data is mandatory.** Every entity in `<meta name="mock-entities">` must have a corresponding `<script type="application/json" id="mock-<entity>">` block with the JSON inlined verbatim from `assets/<entity>.json`.
3. **One screen component per wireframe screen.** Naming: `<PascalCaseSlug>Screen` (e.g., `UserDetailScreen` for `user-detail` slug).
4. **Every screen component must register on `window.__screens`.**
5. **Use atoms from `window.__protoComponents`.** No raw `<button>` or `<input>` elements in screens — only inside the atoms themselves.
6. **No external network calls.** Everything routes through `mockApi` or `store`.
7. **No `console.log` / `console.error` / `console.warn`** in production paths. Debug logs are findings.
8. **No `Lorem ipsum`, no `User 1`, no placeholder copy.** Use real values from the mock data.
9. **Forms must call `mockApi.post / put` and handle the resolved Promise** (loading → success/error toast → optional navigate).
10. **Every async render must show a loading state** (Spinner or skeleton) until data is available.
11. **NotFoundScreen must always exist** so the router has a fallback.
12. **GlobalToasts must always exist** even if not used immediately — Phase 6 reviewers expect it.

## Sizing

Per device file: target 600–1500 lines depending on screen count. If a single device file exceeds 2000 lines, the subagent factors screens into a second `<script type="text/babel">` block grouped by area (e.g., onboarding screens vs. dashboard screens) — but stays within the same single HTML file.
