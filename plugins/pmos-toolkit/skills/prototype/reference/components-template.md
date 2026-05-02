# components.js Template

`assets/components.js` exposes shared atoms on `window.__protoComponents` so device files can use them inside `<script type="text/babel">` blocks. Loaded as a Babel-compiled file or as plain JS using `React.createElement` (the subagent picks based on whether it can guarantee Babel runs over this file too — see "Loading strategy" below).

## Loading strategy

The device HTML loads scripts in this order:

```html
<script src="https://unpkg.com/react@18/umd/react.development.js"></script>
<script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
<script src="./assets/runtime.js"></script>
<!-- components.js is Babel-compiled at runtime -->
<script type="text/babel" src="./assets/components.js" data-presets="react"></script>
```

`<script type="text/babel" src="…">` works with Babel Standalone — it fetches and compiles JSX. This lets components.js use JSX directly, matching how authors will write screens. (Note: this requires the file to be fetchable; the same fetch-fallback that mock-data uses does NOT apply here, so on `file://` browsers must allow cross-origin fetch of local JS. If this proves flaky, the subagent inlines components.js into a `<script type="text/babel">` block in each device file instead — this is the failsafe.)

## Required atoms (on `window.__protoComponents`)

Every atom consumes CSS classes from `prototype.css`. None of them define their own colors, fonts, or spacing inline.

### Button
```jsx
const Button = ({ variant = 'primary', onClick, children, disabled, loading, type = 'button', ariaLabel }) => (
  <button
    type={type}
    className={`btn btn--${variant} ${loading ? 'btn--loading' : ''}`}
    onClick={onClick}
    disabled={disabled || loading}
    aria-label={ariaLabel}>
    {loading ? <Spinner size="sm" /> : children}
  </button>
);
// variants: primary | secondary | destructive | ghost | link
```

### Input
```jsx
const Input = ({ label, value, onChange, error, type = 'text', placeholder, required, name, autoComplete }) => (
  <label className={`field ${error ? 'field--error' : ''}`}>
    <span className="field__label">{label}{required && <span className="field__required" aria-label="required">*</span>}</span>
    <input
      className="field__input"
      type={type}
      name={name}
      value={value}
      onChange={e => onChange(e.target.value)}
      placeholder={placeholder}
      autoComplete={autoComplete}
      aria-invalid={!!error}
      aria-describedby={error ? `${name}-error` : undefined} />
    {error && <span id={`${name}-error`} className="field__error" role="alert">{error}</span>}
  </label>
);
```

### Modal
```jsx
const Modal = ({ open, onClose, title, children, footer, size = 'md' }) => {
  React.useEffect(() => {
    if (!open) return;
    const onKey = e => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);
  if (!open) return null;
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className={`modal modal--${size}`} onClick={e => e.stopPropagation()} role="dialog" aria-modal="true" aria-labelledby="modal-title">
        <header className="modal__header">
          <h2 id="modal-title" className="modal__title">{title}</h2>
          <button className="modal__close" onClick={onClose} aria-label="Close">×</button>
        </header>
        <div className="modal__body">{children}</div>
        {footer && <footer className="modal__footer">{footer}</footer>}
      </div>
    </div>
  );
};
```

### Toast
```jsx
const Toast = ({ type = 'info', message, onDismiss, autoDismissMs = 4000 }) => {
  React.useEffect(() => {
    if (!autoDismissMs) return;
    const t = setTimeout(onDismiss, autoDismissMs);
    return () => clearTimeout(t);
  }, []);
  return (
    <div className={`toast toast--${type}`} role="status">
      <span className="toast__message">{message}</span>
      <button className="toast__dismiss" onClick={onDismiss} aria-label="Dismiss">×</button>
    </div>
  );
};
// types: success | error | info | warning
```

### Card
```jsx
const Card = ({ header, footer, children, onClick, className = '' }) => (
  <div className={`card ${onClick ? 'card--clickable' : ''} ${className}`} onClick={onClick}>
    {header && <header className="card__header">{header}</header>}
    <div className="card__body">{children}</div>
    {footer && <footer className="card__footer">{footer}</footer>}
  </div>
);
```

### Table
```jsx
const Table = ({ columns, rows, onRowClick, loading, emptyState }) => {
  if (loading) return <TableSkeleton rows={5} columns={columns.length} />;
  if (!rows?.length) return emptyState || <EmptyState title="No records" />;
  return (
    <table className="table">
      <thead>
        <tr>{columns.map(c => <th key={c.key} scope="col">{c.label}</th>)}</tr>
      </thead>
      <tbody>
        {rows.map(row => (
          <tr key={row.id} onClick={onRowClick ? () => onRowClick(row) : undefined} tabIndex={onRowClick ? 0 : -1}>
            {columns.map(c => <td key={c.key}>{c.render ? c.render(row) : row[c.key]}</td>)}
          </tr>
        ))}
      </tbody>
    </table>
  );
};
```

### EmptyState
```jsx
const EmptyState = ({ icon = '📭', title, description, cta }) => (
  <div className="empty-state">
    <div className="empty-state__icon" aria-hidden="true">{icon}</div>
    <h3 className="empty-state__title">{title}</h3>
    {description && <p className="empty-state__description">{description}</p>}
    {cta}
  </div>
);
```

### Spinner
```jsx
const Spinner = ({ size = 'md', label = 'Loading' }) => (
  <span className={`spinner spinner--${size}`} role="status" aria-label={label} />
);
// sizes: sm | md | lg
```

### Badge
```jsx
const Badge = ({ tone = 'neutral', children }) => (
  <span className={`badge badge--${tone}`}>{children}</span>
);
// tones: success | warning | danger | info | neutral
```

### Avatar
```jsx
const Avatar = ({ name, src, size = 'md' }) => {
  const initials = name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
  return src
    ? <img className={`avatar avatar--${size}`} src={src} alt={name} />
    : <span className={`avatar avatar--${size} avatar--initials`} aria-label={name}>{initials}</span>;
};
```

### TableSkeleton (internal helper)
```jsx
const TableSkeleton = ({ rows, columns }) => (
  <table className="table table--loading">
    <tbody>
      {Array.from({ length: rows }).map((_, i) => (
        <tr key={i}>
          {Array.from({ length: columns }).map((_, j) => (
            <td key={j}><span className="skeleton skeleton--text" /></td>
          ))}
        </tr>
      ))}
    </tbody>
  </table>
);
```

## File structure (MANDATORY IIFE wrap)

`components.js` is loaded as `<script type="text/babel" src="./assets/components.js">`. Babel-standalone compiles every Babel block into the SAME shared global scope as inline `<script type="text/babel">` blocks in the device HTML — so top-level `const Button = …` here collides with `const { Button } = window.__protoComponents` in screen blocks ("Identifier 'Button' has already been declared" — fatal on first load).

The entire file body MUST be wrapped in an IIFE:

```jsx
(function () {
  const Button = ({ … }) => ( … );
  const Input = ({ … }) => ( … );
  // … all atoms …

  window.__protoComponents = { Button, Input, Modal, Toast, Card, Table, EmptyState, Spinner, Badge, Avatar };
})();
```

Only the `window.__protoComponents` assignment escapes the closure — everything else stays scoped. Same rule applies to `runtime.js` (publishes `window.__proto`) and any `components-extra.js`.

## Footer (the last lines of components.js, inside the IIFE)

```javascript
  window.__protoComponents = { Button, Input, Modal, Toast, Card, Table, EmptyState, Spinner, Badge, Avatar };
})();
```

## Subagent rules

- All atoms above are mandatory; subagent does not skip any (even if a screen doesn't use Toast yet, screens added later will).
- Subagent may ADD atoms specific to the feature (e.g., `Stepper` for multi-step forms, `KPI` for dashboard cards) — append them to the export footer.
- Total file ≤ 350 lines. If it grows, factor feature-specific atoms into `assets/components-extra.js`.
- Every atom must be keyboard-accessible by default.
- Every atom must respect `disabled` / `aria-*` props passed in.
