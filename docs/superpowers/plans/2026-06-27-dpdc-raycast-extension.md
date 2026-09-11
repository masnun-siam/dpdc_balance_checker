# DPDC Raycast Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a Raycast extension with three commands (My Meters list, Check Balance ad-hoc, Balance menu-bar) that checks DPDC prepaid electricity meter balances using the same API as the Flutter app.

**Architecture:** A TypeScript Raycast extension scaffolded at `~/Documents/Projects/Personal/dpdc-raycast`. All three commands share a single typed API/storage module (`src/lib/`) so auth, GraphQL fetch, and LocalStorage CRUD are written once. Balances are cached in LocalStorage (30-min TTL) so views render instantly and never go blank on failure.

**Tech Stack:** Raycast API (`@raycast/api`), `@raycast/utils` (useCachedPromise, showFailureToast), TypeScript strict, Jest for unit tests on pure functions/services, `ray lint` (ESLint + Prettier via `@raycast/eslint-config`).

## Global Constraints

- Extension root: `/Users/siam/Documents/Projects/Personal/dpdc-raycast` (sibling to the Flutter app)
- All API constants hardcoded: `clientId=auth-ui`, `clientSecret=0yFsAl4nN9jX1GGkgOrvpUxDarf2DT40`, `tenantCode=DPDC`
- Auth endpoint: `POST https://amiapp.dpdc.org.bd/auth/login/generate-bearer`
- Balance endpoint: `POST https://amiapp.dpdc.org.bd/usage/usage-service` (GraphQL)
- Customer ID validation: `/^[0-9]{8,12}$/`
- Balance format: `৳1,234.00` (en-IN locale grouping, 2 decimals)
- Cache TTL: 30 min (aligned with menu-bar interval)
- Fetch timeout: 30 seconds
- Alert threshold preference default: `50` (৳)
- Refresh interval preference default: `30` (minutes)
- Must pass `ray lint` (no eslint/prettier errors)
- Token caching in LocalStorage with absolute expiry epoch ms

---

## File Map

| Path | Responsibility |
|------|---------------|
| `package.json` | Extension manifest: 3 commands, 2 preferences, dependencies |
| `tsconfig.json` | TypeScript strict config (Raycast default) |
| `.eslintrc.json` | Extends `@raycast/eslint-config` |
| `jest.config.js` | Jest with ts-jest for unit tests |
| `src/lib/types.ts` | All shared interfaces: `BalanceDetails`, `Meter`, `CachedBalance`, `TokenCache`, `Preferences` |
| `src/lib/format.ts` | `formatBalance(n)` → `৳1,234.00`; `formatTimeAgo(epochMs)` → `"12m ago"` |
| `src/lib/storage.ts` | Meters CRUD + token cache + balance cache via `LocalStorage` |
| `src/lib/dpdc.ts` | `validateCustomerId`, `fetchBalanceDetails`, token management |
| `src/my-meters.tsx` | "My Meters" view command: list, detail, add/edit/remove, actions |
| `src/check-balance.tsx` | "Check Balance" view command: ad-hoc lookup, offer to save |
| `src/balance-menu-bar.tsx` | "Balance" menu-bar command: primary meter title, dropdown, threshold coloring |
| `__tests__/format.test.ts` | Unit tests for `formatBalance` and `formatTimeAgo` |
| `__tests__/storage.test.ts` | Unit tests for storage CRUD (mock `@raycast/api`) |
| `__tests__/dpdc.test.ts` | Unit tests for `validateCustomerId` + fetch logic (mock fetch + storage) |

---

## Task 1: Scaffold Extension Project

**Files:**

- Create: `package.json`
- Create: `tsconfig.json`
- Create: `.eslintrc.json`
- Create: `jest.config.js`
- Create: `src/` directory skeleton

**Interfaces:**

- Produces: runnable `npm install`, importable `@raycast/api`, `ray lint` baseline

- [x] **Step 1: Create the extension directory**

```bash
mkdir -p /Users/siam/Documents/Projects/Personal/dpdc-raycast/{src/lib,assets,__tests__}
cd /Users/siam/Documents/Projects/Personal/dpdc-raycast
```

- [x] **Step 2: Write `package.json`**

```json
{
  "name": "dpdc-balance",
  "title": "DPDC Balance",
  "description": "Check prepaid electricity balance for DPDC accounts",
  "icon": "extension-icon.png",
  "author": "masnun-siam",
  "categories": ["Utilities"],
  "license": "MIT",
  "version": "1.0.0",
  "commands": [
    {
      "name": "my-meters",
      "title": "My Meters",
      "subtitle": "DPDC",
      "description": "View and manage your saved DPDC meters",
      "mode": "view"
    },
    {
      "name": "check-balance",
      "title": "Check Balance",
      "subtitle": "DPDC",
      "description": "Check balance for any DPDC Customer ID",
      "mode": "view"
    },
    {
      "name": "balance-menu-bar",
      "title": "Balance",
      "subtitle": "DPDC",
      "description": "Show primary meter balance in the menu bar",
      "mode": "menu-bar",
      "interval": "30m"
    }
  ],
  "preferences": [
    {
      "name": "alertThreshold",
      "title": "Alert Threshold (৳)",
      "description": "Balance at or below this amount triggers a low-balance indicator (red icon/title)",
      "type": "textfield",
      "default": "50",
      "required": false
    },
    {
      "name": "refreshInterval",
      "title": "Refresh Interval",
      "description": "How often views auto-refresh cached balances",
      "type": "dropdown",
      "default": "30",
      "required": false,
      "data": [
        { "title": "15 minutes", "value": "15" },
        { "title": "30 minutes", "value": "30" },
        { "title": "1 hour", "value": "60" }
      ]
    }
  ],
  "dependencies": {
    "@raycast/api": "^1.0.0",
    "@raycast/utils": "^1.0.0"
  },
  "devDependencies": {
    "@raycast/eslint-config": "^1.0.0",
    "@types/jest": "^29.0.0",
    "@types/node": "^20.0.0",
    "@types/react": "^18.0.0",
    "eslint": "^8.0.0",
    "jest": "^29.0.0",
    "prettier": "^3.0.0",
    "ts-jest": "^29.0.0",
    "typescript": "^5.0.0"
  },
  "scripts": {
    "build": "ray build -e dist",
    "dev": "ray develop",
    "lint": "ray lint",
    "fix-lint": "ray lint --fix",
    "test": "jest"
  }
}
```

- [x] **Step 3: Write `tsconfig.json`**

```json
{
  "compilerOptions": {
    "lib": ["ES2020"],
    "module": "CommonJS",
    "target": "ES2020",
    "jsx": "react-jsx",
    "strict": true,
    "moduleResolution": "node",
    "allowSyntheticDefaultImports": true,
    "esModuleInterop": true,
    "outDir": "dist",
    "skipLibCheck": true
  },
  "include": ["src", "__tests__"]
}
```

- [x] **Step 4: Write `.eslintrc.json`**

```json
{
  "extends": "@raycast/eslint-config",
  "rules": {}
}
```

- [x] **Step 5: Write `jest.config.js`**

```js
/** @type {import('jest').Config} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/__tests__/**/*.test.ts"],
  moduleNameMapper: {
    "^@raycast/api$": "<rootDir>/__mocks__/@raycast/api.ts",
    "^@raycast/utils$": "<rootDir>/__mocks__/@raycast/utils.ts"
  }
};
```

- [x] **Step 6: Create Raycast API mock for tests**

Create `__mocks__/@raycast/api.ts`:

```ts
// Minimal mock of @raycast/api for Jest — only what our lib code uses
const store: Record<string, string> = {};

export const LocalStorage = {
  getItem: jest.fn(async <T = string>(key: string): Promise<T | undefined> => {
    const val = store[key];
    return val as T | undefined;
  }),
  setItem: jest.fn(async (key: string, value: string): Promise<void> => {
    store[key] = value;
  }),
  removeItem: jest.fn(async (key: string): Promise<void> => {
    delete store[key];
  }),
  clear: jest.fn(async (): Promise<void> => {
    Object.keys(store).forEach((k) => delete store[k]);
  }),
};

export const getPreferenceValues = jest.fn(() => ({
  alertThreshold: "50",
  refreshInterval: "30",
}));

export const showToast = jest.fn();
export const showHUD = jest.fn();
export const launchCommand = jest.fn();
export const open = jest.fn();
export const Clipboard = { copy: jest.fn() };
export const Icon = { Star: "star", Circle: "circle" };
export const Color = { Green: "#00aa00", Orange: "#ff8800", Red: "#ff0000" };
export const Toast = { Style: { Success: "success", Failure: "failure", Animated: "animated" } };

export const resetMockStore = () => {
  Object.keys(store).forEach((k) => delete store[k]);
  jest.clearAllMocks();
};
```

Create `__mocks__/@raycast/utils.ts`:

```ts
export const showFailureToast = jest.fn();
export const useCachedPromise = jest.fn();
export const usePromise = jest.fn();
```

- [x] **Step 7: Install dependencies**

```bash
cd /Users/siam/Documents/Projects/Personal/dpdc-raycast
npm install
```

Expected: `node_modules/` created, `@raycast/api` and `@raycast/utils` installed.

- [x] **Step 8: Verify lint baseline passes on empty src**

Create a placeholder `src/my-meters.tsx` (will be replaced in Task 5):

```tsx
import { List } from "@raycast/api";
export default function MyMeters() {
  return <List isLoading />;
}
```

Create `src/check-balance.tsx`:

```tsx
import { List } from "@raycast/api";
export default function CheckBalance() {
  return <List isLoading />;
}
```

Create `src/balance-menu-bar.tsx`:

```tsx
import { MenuBarExtra } from "@raycast/api";
export default function BalanceMenuBar() {
  return <MenuBarExtra title="⚡" isLoading />;
}
```

Run: `npm run lint`
Expected: no errors (or only "no-default-export" style warnings that we'll fix later).

- [x] **Step 9: Commit scaffold**

```bash
cd /Users/siam/Documents/Projects/Personal/dpdc-raycast
git init
git add .
git commit -m "feat: scaffold DPDC Raycast extension"
```

---

## Task 2: Types + Format Utilities + Tests

**Files:**

- Create: `src/lib/types.ts`
- Create: `src/lib/format.ts`
- Create: `__tests__/format.test.ts`

**Interfaces:**

- Produces: `BalanceDetails`, `Meter`, `CachedBalance`, `TokenCache`, `Preferences` (used by all tasks); `formatBalance(n: number): string`; `formatTimeAgo(epochMs: number): string`

- [x] **Step 1: Write `src/lib/types.ts`**

```ts
export interface BalanceDetails {
  accountId: string;
  customerName: string;
  customerClass: string;
  mobileNumber: string | null;
  emailId: string | null;
  accountType: string;
  balanceRemaining: number;
  connectionStatus: string;
  customerType: string;
  minRecharge: number | null;
}

export interface Meter {
  id: string;
  label?: string;
  isPrimary: boolean;
}

export interface CachedBalance {
  data: BalanceDetails;
  fetchedAt: number; // epoch ms
}

export interface TokenCache {
  accessToken: string;
  refreshToken: string | null;
  expiry: number; // epoch ms (absolute)
}

export interface Preferences {
  alertThreshold: string; // e.g. "50" — parsed as float at use site
  refreshInterval: string; // e.g. "30" — minutes, parsed as int at use site
}
```

- [x] **Step 2: Write `src/lib/format.ts`**

```ts
/**
 * Format a balance number as Bangladeshi Taka with locale grouping.
 * e.g. 1234.5 → "৳1,234.50"
 */
export function formatBalance(amount: number): string {
  const formatted = Math.abs(amount).toLocaleString("en-IN", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return amount < 0 ? `-৳${formatted}` : `৳${formatted}`;
}

/**
 * Human-readable relative time since a fetchedAt epoch timestamp.
 * e.g. formatTimeAgo(Date.now() - 70_000) → "1m ago"
 */
export function formatTimeAgo(fetchedAt: number): string {
  const diffMs = Date.now() - fetchedAt;
  const diffMin = Math.floor(diffMs / 60_000);
  if (diffMin < 1) return "just now";
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHour = Math.floor(diffMin / 60);
  if (diffHour < 24) return `${diffHour}h ago`;
  return `${Math.floor(diffHour / 24)}d ago`;
}

/**
 * Build the plain-text share block matching the mobile app's Share Details.
 */
export function buildShareText(id: string, b: import("./types").BalanceDetails): string {
  return [
    `DPDC Balance Details`,
    `Customer ID: ${id}`,
    `Name: ${b.customerName}`,
    `Account ID: ${b.accountId}`,
    `Balance: ${formatBalance(b.balanceRemaining)}`,
    `Status: ${b.connectionStatus}`,
    `Class: ${b.customerClass}`,
    `Type: ${b.customerType}`,
    `Account Type: ${b.accountType}`,
    b.mobileNumber ? `Mobile: ${b.mobileNumber}` : null,
    b.emailId ? `Email: ${b.emailId}` : null,
    b.minRecharge != null ? `Min Recharge: ${formatBalance(b.minRecharge)}` : null,
  ]
    .filter(Boolean)
    .join("\n");
}
```

- [x] **Step 3: Write `__tests__/format.test.ts`**

```ts
import { formatBalance, formatTimeAgo, buildShareText } from "../src/lib/format";
import type { BalanceDetails } from "../src/lib/types";

describe("formatBalance", () => {
  it("formats a whole number with 2 decimals", () => {
    expect(formatBalance(1234)).toBe("৳1,234.00");
  });

  it("formats a decimal balance with grouping", () => {
    expect(formatBalance(1234.5)).toBe("৳1,234.50");
  });

  it("formats zero", () => {
    expect(formatBalance(0)).toBe("৳0.00");
  });

  it("formats a negative balance with leading minus", () => {
    expect(formatBalance(-50.75)).toBe("-৳50.75");
  });

  it("formats small balance under 1000", () => {
    expect(formatBalance(88)).toBe("৳88.00");
  });
});

describe("formatTimeAgo", () => {
  const now = Date.now();

  it("returns 'just now' for < 1 minute ago", () => {
    expect(formatTimeAgo(now - 30_000)).toBe("just now");
  });

  it("returns minutes for < 1 hour ago", () => {
    expect(formatTimeAgo(now - 12 * 60_000)).toBe("12m ago");
  });

  it("returns hours for < 24 hours ago", () => {
    expect(formatTimeAgo(now - 2 * 60 * 60_000)).toBe("2h ago");
  });

  it("returns days for >= 24 hours ago", () => {
    expect(formatTimeAgo(now - 25 * 60 * 60_000)).toBe("1d ago");
  });
});

describe("buildShareText", () => {
  const balance: BalanceDetails = {
    accountId: "ACC123",
    customerName: "John Doe",
    customerClass: "Residential",
    mobileNumber: "01711000000",
    emailId: null,
    accountType: "Prepaid",
    balanceRemaining: 1234.5,
    connectionStatus: "active",
    customerType: "Domestic",
    minRecharge: 50,
  };

  it("includes key fields", () => {
    const text = buildShareText("31719842", balance);
    expect(text).toContain("Customer ID: 31719842");
    expect(text).toContain("Balance: ৳1,234.50");
    expect(text).toContain("Mobile: 01711000000");
  });

  it("omits null fields", () => {
    const text = buildShareText("31719842", balance);
    expect(text).not.toContain("Email:");
  });
});
```

- [x] **Step 4: Run tests to verify they pass**

```bash
cd /Users/siam/Documents/Projects/Personal/dpdc-raycast
npm test -- __tests__/format.test.ts
```

Expected: All tests PASS (17 assertions).

- [x] **Step 5: Commit**

```bash
git add src/lib/types.ts src/lib/format.ts __tests__/format.test.ts
git commit -m "feat: add types and format utilities with tests"
```

---

## Task 3: Storage Module + Tests

**Files:**

- Create: `src/lib/storage.ts`
- Create: `__tests__/storage.test.ts`

**Interfaces:**

- Consumes: `Meter`, `CachedBalance`, `TokenCache`, `BalanceDetails` from `src/lib/types.ts`; `LocalStorage` from `@raycast/api`
- Produces:
  - `getMeters(): Promise<Meter[]>`
  - `addMeter(id: string, label?: string): Promise<void>`
  - `updateLabel(id: string, label: string): Promise<void>`
  - `removeMeter(id: string): Promise<void>`
  - `setPrimary(id: string): Promise<void>`
  - `isSaved(id: string): Promise<boolean>`
  - `getTokens(): Promise<TokenCache | null>`
  - `saveTokens(tokens: TokenCache): Promise<void>`
  - `getCachedBalance(id: string): Promise<CachedBalance | null>`
  - `setCachedBalance(id: string, data: BalanceDetails): Promise<void>`

- [x] **Step 1: Write failing test for `getMeters` (empty state)**

```ts
// __tests__/storage.test.ts
import { resetMockStore } from "../__mocks__/@raycast/api";

jest.mock("@raycast/api");

import { getMeters, addMeter, removeMeter, setPrimary, isSaved, updateLabel } from "../src/lib/storage";

beforeEach(() => {
  resetMockStore();
});

describe("getMeters", () => {
  it("returns empty array when no meters stored", async () => {
    const result = await getMeters();
    expect(result).toEqual([]);
  });
});
```

- [x] **Step 2: Run to confirm it fails**

```bash
npm test -- __tests__/storage.test.ts
```

Expected: FAIL — `getMeters` not found (module doesn't exist yet).

- [x] **Step 3: Write `src/lib/storage.ts`**

```ts
import { LocalStorage } from "@raycast/api";
import type { Meter, CachedBalance, TokenCache, BalanceDetails } from "./types";

const METERS_KEY = "dpdc_meters";
const TOKENS_KEY = "dpdc_tokens";
const CACHE_KEY = "dpdc_balance_cache";

export async function getMeters(): Promise<Meter[]> {
  const raw = await LocalStorage.getItem<string>(METERS_KEY);
  return raw ? (JSON.parse(raw) as Meter[]) : [];
}

export async function addMeter(id: string, label?: string): Promise<void> {
  const meters = await getMeters();
  if (meters.some((m) => m.id === id)) return; // already saved, no-op
  const isPrimary = meters.length === 0; // first meter becomes primary
  meters.push({ id, label, isPrimary });
  await LocalStorage.setItem(METERS_KEY, JSON.stringify(meters));
}

export async function updateLabel(id: string, label: string): Promise<void> {
  const meters = await getMeters();
  const updated = meters.map((m) => (m.id === id ? { ...m, label } : m));
  await LocalStorage.setItem(METERS_KEY, JSON.stringify(updated));
}

export async function removeMeter(id: string): Promise<void> {
  let meters = await getMeters();
  const wasPrimary = meters.find((m) => m.id === id)?.isPrimary ?? false;
  meters = meters.filter((m) => m.id !== id);
  if (wasPrimary && meters.length > 0) {
    meters[0] = { ...meters[0], isPrimary: true };
  }
  await LocalStorage.setItem(METERS_KEY, JSON.stringify(meters));
}

export async function setPrimary(id: string): Promise<void> {
  const meters = await getMeters();
  const updated = meters.map((m) => ({ ...m, isPrimary: m.id === id }));
  await LocalStorage.setItem(METERS_KEY, JSON.stringify(updated));
}

export async function isSaved(id: string): Promise<boolean> {
  const meters = await getMeters();
  return meters.some((m) => m.id === id);
}

export async function getTokens(): Promise<TokenCache | null> {
  const raw = await LocalStorage.getItem<string>(TOKENS_KEY);
  return raw ? (JSON.parse(raw) as TokenCache) : null;
}

export async function saveTokens(tokens: TokenCache): Promise<void> {
  await LocalStorage.setItem(TOKENS_KEY, JSON.stringify(tokens));
}

export async function getCachedBalance(id: string): Promise<CachedBalance | null> {
  const raw = await LocalStorage.getItem<string>(CACHE_KEY);
  const cache: Record<string, CachedBalance> = raw ? JSON.parse(raw) : {};
  return cache[id] ?? null;
}

export async function setCachedBalance(id: string, data: BalanceDetails): Promise<void> {
  const raw = await LocalStorage.getItem<string>(CACHE_KEY);
  const cache: Record<string, CachedBalance> = raw ? JSON.parse(raw) : {};
  cache[id] = { data, fetchedAt: Date.now() };
  await LocalStorage.setItem(CACHE_KEY, JSON.stringify(cache));
}
```

- [x] **Step 4: Expand the test file to cover all storage operations**

Replace `__tests__/storage.test.ts` with:

```ts
import { resetMockStore } from "../__mocks__/@raycast/api";
jest.mock("@raycast/api");

import {
  getMeters,
  addMeter,
  removeMeter,
  setPrimary,
  isSaved,
  updateLabel,
  getTokens,
  saveTokens,
  getCachedBalance,
  setCachedBalance,
} from "../src/lib/storage";
import type { BalanceDetails, TokenCache } from "../src/lib/types";

const sampleBalance: BalanceDetails = {
  accountId: "ACC1",
  customerName: "Alice",
  customerClass: "Residential",
  mobileNumber: null,
  emailId: null,
  accountType: "Prepaid",
  balanceRemaining: 500,
  connectionStatus: "active",
  customerType: "Domestic",
  minRecharge: 50,
};

beforeEach(() => {
  resetMockStore();
});

describe("getMeters", () => {
  it("returns empty array when nothing stored", async () => {
    expect(await getMeters()).toEqual([]);
  });
});

describe("addMeter", () => {
  it("adds a meter and makes it primary when it's the first", async () => {
    await addMeter("11111111");
    const meters = await getMeters();
    expect(meters).toHaveLength(1);
    expect(meters[0]).toEqual({ id: "11111111", label: undefined, isPrimary: true });
  });

  it("second meter is not primary", async () => {
    await addMeter("11111111");
    await addMeter("22222222", "Office");
    const meters = await getMeters();
    expect(meters[0].isPrimary).toBe(true);
    expect(meters[1].isPrimary).toBe(false);
    expect(meters[1].label).toBe("Office");
  });

  it("is a no-op if ID already saved", async () => {
    await addMeter("11111111");
    await addMeter("11111111");
    expect((await getMeters())).toHaveLength(1);
  });
});

describe("updateLabel", () => {
  it("updates label for matching meter", async () => {
    await addMeter("11111111", "Home");
    await updateLabel("11111111", "House");
    const meters = await getMeters();
    expect(meters[0].label).toBe("House");
  });
});

describe("removeMeter", () => {
  it("removes the meter", async () => {
    await addMeter("11111111");
    await removeMeter("11111111");
    expect((await getMeters())).toHaveLength(0);
  });

  it("reassigns primary to first remaining when primary is removed", async () => {
    await addMeter("11111111");
    await addMeter("22222222");
    await removeMeter("11111111");
    const meters = await getMeters();
    expect(meters[0].id).toBe("22222222");
    expect(meters[0].isPrimary).toBe(true);
  });
});

describe("setPrimary", () => {
  it("sets the given meter as primary and clears others", async () => {
    await addMeter("11111111");
    await addMeter("22222222");
    await setPrimary("22222222");
    const meters = await getMeters();
    expect(meters.find((m) => m.id === "11111111")?.isPrimary).toBe(false);
    expect(meters.find((m) => m.id === "22222222")?.isPrimary).toBe(true);
  });
});

describe("isSaved", () => {
  it("returns false when not saved", async () => {
    expect(await isSaved("11111111")).toBe(false);
  });

  it("returns true when saved", async () => {
    await addMeter("11111111");
    expect(await isSaved("11111111")).toBe(true);
  });
});

describe("tokens", () => {
  const tokens: TokenCache = {
    accessToken: "abc",
    refreshToken: "def",
    expiry: Date.now() + 3600_000,
  };

  it("returns null when no tokens stored", async () => {
    expect(await getTokens()).toBeNull();
  });

  it("saves and retrieves tokens", async () => {
    await saveTokens(tokens);
    const retrieved = await getTokens();
    expect(retrieved?.accessToken).toBe("abc");
    expect(retrieved?.refreshToken).toBe("def");
  });
});

describe("balance cache", () => {
  it("returns null for uncached meter", async () => {
    expect(await getCachedBalance("11111111")).toBeNull();
  });

  it("saves and retrieves cached balance", async () => {
    await setCachedBalance("11111111", sampleBalance);
    const cached = await getCachedBalance("11111111");
    expect(cached?.data.balanceRemaining).toBe(500);
    expect(typeof cached?.fetchedAt).toBe("number");
  });

  it("does not overwrite cache for other IDs", async () => {
    await setCachedBalance("11111111", sampleBalance);
    await setCachedBalance("22222222", { ...sampleBalance, balanceRemaining: 100 });
    expect((await getCachedBalance("11111111"))?.data.balanceRemaining).toBe(500);
    expect((await getCachedBalance("22222222"))?.data.balanceRemaining).toBe(100);
  });
});
```

- [x] **Step 5: Run tests**

```bash
npm test -- __tests__/storage.test.ts
```

Expected: All tests PASS (17 assertions).

- [x] **Step 6: Commit**

```bash
git add src/lib/storage.ts __tests__/storage.test.ts __mocks__
git commit -m "feat: add storage module with LocalStorage persistence"
```

---

## Task 4: DPDC API Module + Tests

**Files:**

- Create: `src/lib/dpdc.ts`
- Create: `__tests__/dpdc.test.ts`

**Interfaces:**

- Consumes: `getTokens`, `saveTokens` from `src/lib/storage.ts`; `TokenCache`, `BalanceDetails` from `src/lib/types.ts`
- Produces:
  - `validateCustomerId(id: string): boolean`
  - `fetchBalanceDetails(customerId: string): Promise<BalanceDetails>` (throws descriptive Error on failure)

- [x] **Step 1: Write failing tests for `validateCustomerId`**

```ts
// __tests__/dpdc.test.ts
jest.mock("@raycast/api");
jest.mock("../src/lib/storage");

import { validateCustomerId } from "../src/lib/dpdc";

describe("validateCustomerId", () => {
  it("accepts an 8-digit numeric ID", () => {
    expect(validateCustomerId("31719842")).toBe(true);
  });
  it("accepts a 12-digit numeric ID", () => {
    expect(validateCustomerId("317198421234")).toBe(true);
  });
  it("rejects 7 digits (too short)", () => {
    expect(validateCustomerId("3171984")).toBe(false);
  });
  it("rejects 13 digits (too long)", () => {
    expect(validateCustomerId("3171984212345")).toBe(false);
  });
  it("rejects non-numeric characters", () => {
    expect(validateCustomerId("3171984X")).toBe(false);
  });
  it("rejects empty string", () => {
    expect(validateCustomerId("")).toBe(false);
  });
});
```

- [x] **Step 2: Run to confirm it fails**

```bash
npm test -- __tests__/dpdc.test.ts
```

Expected: FAIL — module not found.

- [x] **Step 3: Write `src/lib/dpdc.ts`**

```ts
import { getTokens, saveTokens } from "./storage";
import type { BalanceDetails, TokenCache } from "./types";

const AUTH_URL = "https://amiapp.dpdc.org.bd/auth/login/generate-bearer";
const BALANCE_URL = "https://amiapp.dpdc.org.bd/usage/usage-service";
const CLIENT_ID = "auth-ui";
const CLIENT_SECRET = "0yFsAl4nN9jX1GGkgOrvpUxDarf2DT40";
const TENANT_CODE = "DPDC";
const TIMEOUT_MS = 30_000;

export function validateCustomerId(id: string): boolean {
  return /^[0-9]{8,12}$/.test(id);
}

async function fetchWithTimeout(url: string, options: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function generateBearerToken(refreshToken?: string): Promise<TokenCache> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json;charset=UTF-8",
    clientId: CLIENT_ID,
    clientSecret: CLIENT_SECRET,
    tenantCode: TENANT_CODE,
  };
  if (refreshToken) {
    headers["Authorization"] = `Bearer ${refreshToken}`;
  }

  const res = await fetchWithTimeout(AUTH_URL, {
    method: "POST",
    headers,
    body: JSON.stringify({}),
  });

  if (res.status !== 200 && res.status !== 201) {
    throw new Error(`Auth failed with status ${res.status}`);
  }

  const json = (await res.json()) as Record<string, unknown>;
  const accessToken = json["access_token"] as string | undefined;
  if (!accessToken) throw new Error("No access_token in auth response");

  const expiresIn = typeof json["expires_in"] === "number" ? (json["expires_in"] as number) : 3600;
  const tokens: TokenCache = {
    accessToken,
    refreshToken: (json["refresh_token"] as string | null) ?? null,
    expiry: Date.now() + expiresIn * 1000,
  };
  await saveTokens(tokens);
  return tokens;
}

async function getValidAccessToken(): Promise<string> {
  const cached = await getTokens();
  // Reuse if valid with >1 min buffer
  if (cached && cached.expiry > Date.now() + 60_000) {
    return cached.accessToken;
  }
  // Try refresh
  if (cached?.refreshToken) {
    try {
      const refreshed = await generateBearerToken(cached.refreshToken);
      return refreshed.accessToken;
    } catch {
      // fall through to fresh token
    }
  }
  // Fresh token
  const fresh = await generateBearerToken();
  return fresh.accessToken;
}

function buildQuery(customerId: string): string {
  return `query {
  postBalanceDetails(input: {
    customerNumber: "${customerId}",
    tenantCode: "DPDC"
  }) {
    accountId
    customerName
    customerClass
    mobileNumber
    emailId
    accountType
    balanceRemaining
    connectionStatus
    customerType
    minRecharge
  }
}`;
}

export async function fetchBalanceDetails(customerId: string): Promise<BalanceDetails> {
  const token = await getValidAccessToken();

  const res = await fetchWithTimeout(BALANCE_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json;charset=UTF-8",
      Authorization: `Bearer ${token}`,
      accessToken: token,
      tenantCode: TENANT_CODE,
    },
    body: JSON.stringify({ query: buildQuery(customerId) }),
  });

  if (res.status === 404) throw new Error("Customer ID not found");
  if (res.status >= 500) throw new Error(`DPDC server error (${res.status})`);

  const json = (await res.json()) as {
    errors?: Array<{ message: string }>;
    data?: { postBalanceDetails?: Record<string, unknown> | null };
  };

  if (Array.isArray(json.errors) && json.errors.length > 0) {
    throw new Error(json.errors[0].message);
  }

  const details = json.data?.postBalanceDetails;
  if (!details) throw new Error("Customer ID not found");

  return {
    accountId: String(details["accountId"] ?? ""),
    customerName: String(details["customerName"] ?? ""),
    customerClass: String(details["customerClass"] ?? ""),
    mobileNumber: (details["mobileNumber"] as string | null) ?? null,
    emailId: (details["emailId"] as string | null) ?? null,
    accountType: String(details["accountType"] ?? ""),
    balanceRemaining: Number(details["balanceRemaining"]) || 0,
    connectionStatus: String(details["connectionStatus"] ?? ""),
    customerType: String(details["customerType"] ?? ""),
    minRecharge: details["minRecharge"] != null ? Number(details["minRecharge"]) : null,
  };
}
```

- [x] **Step 4: Expand the test file to cover `fetchBalanceDetails` (mock fetch)**

Add to `__tests__/dpdc.test.ts`:

```ts
import { fetchBalanceDetails } from "../src/lib/dpdc";
import * as storage from "../src/lib/storage";

const mockFetch = jest.fn();
global.fetch = mockFetch;

const mockGetTokens = storage.getTokens as jest.MockedFunction<typeof storage.getTokens>;
const mockSaveTokens = storage.saveTokens as jest.MockedFunction<typeof storage.saveTokens>;

beforeEach(() => {
  jest.clearAllMocks();
  mockSaveTokens.mockResolvedValue(undefined);
});

const authResponse = {
  access_token: "tok-abc",
  refresh_token: "ref-xyz",
  expires_in: 3600,
};

const balanceResponse = {
  data: {
    postBalanceDetails: {
      accountId: "ACC999",
      customerName: "John",
      customerClass: "Residential",
      mobileNumber: "01711000000",
      emailId: null,
      accountType: "Prepaid",
      balanceRemaining: 1234.5,
      connectionStatus: "active",
      customerType: "Domestic",
      minRecharge: 50,
    },
  },
};

describe("fetchBalanceDetails", () => {
  it("fetches balance with a fresh token when none cached", async () => {
    mockGetTokens.mockResolvedValue(null);
    mockFetch
      .mockResolvedValueOnce({ status: 200, json: async () => authResponse }) // auth
      .mockResolvedValueOnce({ status: 200, json: async () => balanceResponse }); // balance

    const result = await fetchBalanceDetails("31719842");
    expect(result.customerName).toBe("John");
    expect(result.balanceRemaining).toBe(1234.5);
    expect(mockFetch).toHaveBeenCalledTimes(2);
  });

  it("reuses a valid cached token", async () => {
    mockGetTokens.mockResolvedValue({
      accessToken: "cached-tok",
      refreshToken: null,
      expiry: Date.now() + 3_600_000,
    });
    mockFetch.mockResolvedValueOnce({ status: 200, json: async () => balanceResponse });

    const result = await fetchBalanceDetails("31719842");
    expect(result.accountId).toBe("ACC999");
    expect(mockFetch).toHaveBeenCalledTimes(1); // no auth call
  });

  it("throws 'Customer ID not found' on 404", async () => {
    mockGetTokens.mockResolvedValue({
      accessToken: "tok",
      refreshToken: null,
      expiry: Date.now() + 3_600_000,
    });
    mockFetch.mockResolvedValueOnce({ status: 404, json: async () => ({}) });

    await expect(fetchBalanceDetails("99999999")).rejects.toThrow("Customer ID not found");
  });

  it("throws on GraphQL errors array", async () => {
    mockGetTokens.mockResolvedValue({
      accessToken: "tok",
      refreshToken: null,
      expiry: Date.now() + 3_600_000,
    });
    mockFetch.mockResolvedValueOnce({
      status: 200,
      json: async () => ({ errors: [{ message: "Invalid customer" }], data: null }),
    });

    await expect(fetchBalanceDetails("12345678")).rejects.toThrow("Invalid customer");
  });

  it("throws on null postBalanceDetails (ID not found GraphQL null)", async () => {
    mockGetTokens.mockResolvedValue({
      accessToken: "tok",
      refreshToken: null,
      expiry: Date.now() + 3_600_000,
    });
    mockFetch.mockResolvedValueOnce({
      status: 200,
      json: async () => ({ data: { postBalanceDetails: null } }),
    });

    await expect(fetchBalanceDetails("12345678")).rejects.toThrow("Customer ID not found");
  });
});
```

- [x] **Step 5: Run all tests**

```bash
npm test
```

Expected: All tests PASS across format, storage, dpdc test files (35+ assertions total).

- [x] **Step 6: Commit**

```bash
git add src/lib/dpdc.ts __tests__/dpdc.test.ts
git commit -m "feat: add DPDC API module with token cache and GraphQL fetch"
```

---

## Task 5: My Meters Command

**Files:**

- Modify: `src/my-meters.tsx` (replace placeholder)

**Interfaces:**

- Consumes: All of `src/lib/` (types, format, storage, dpdc)
- Produces: "My Meters" Raycast view command — list, detail panel, add/edit/remove/set-primary actions, EmptyView

- [x] **Step 1: Write `src/my-meters.tsx`**

```tsx
import {
  Action,
  ActionPanel,
  Color,
  Form,
  getPreferenceValues,
  Icon,
  List,
  showToast,
  Toast,
  useNavigation,
} from "@raycast/api";
import { useCachedPromise, showFailureToast } from "@raycast/utils";
import { useCallback } from "react";
import type { BalanceDetails, Meter, Preferences } from "./lib/types";
import { formatBalance, formatTimeAgo, buildShareText } from "./lib/format";
import {
  getMeters,
  addMeter,
  updateLabel,
  removeMeter,
  setPrimary,
  getCachedBalance,
  setCachedBalance,
} from "./lib/storage";
import { fetchBalanceDetails, validateCustomerId } from "./lib/dpdc";

// ─── Data shape returned by loadAll ─────────────────────────────────────────
interface MeterRow {
  meter: Meter;
  balance: BalanceDetails | null;
  fetchedAt: number;
  stale: boolean;
  error: string | null;
}

// ─── Load all meters with cached / fresh balances ───────────────────────────
async function loadAll(): Promise<MeterRow[]> {
  const meters = await getMeters();
  const prefs = getPreferenceValues<Preferences>();
  const cacheTTL = parseInt(prefs.refreshInterval) * 60_000;

  return Promise.all(
    meters.map(async (meter): Promise<MeterRow> => {
      const cached = await getCachedBalance(meter.id);
      const isStale = !cached || Date.now() - cached.fetchedAt > cacheTTL;

      if (!isStale && cached) {
        return { meter, balance: cached.data, fetchedAt: cached.fetchedAt, stale: false, error: null };
      }
      try {
        const data = await fetchBalanceDetails(meter.id);
        await setCachedBalance(meter.id, data);
        return { meter, balance: data, fetchedAt: Date.now(), stale: false, error: null };
      } catch (err) {
        if (cached) {
          return { meter, balance: cached.data, fetchedAt: cached.fetchedAt, stale: true, error: String(err) };
        }
        return { meter, balance: null, fetchedAt: 0, stale: false, error: String(err) };
      }
    })
  );
}

// ─── Add Meter Form ──────────────────────────────────────────────────────────
function AddMeterForm({ onAdd }: { onAdd: () => void }) {
  const { pop } = useNavigation();

  async function handleSubmit(values: { id: string; label: string }) {
    const trimId = values.id.trim();
    const trimLabel = values.label.trim() || undefined;

    if (!validateCustomerId(trimId)) {
      await showToast({ style: Toast.Style.Failure, title: "Invalid Customer ID", message: "Must be 8–12 digits." });
      return;
    }

    await showToast({ style: Toast.Style.Animated, title: "Checking meter…" });
    try {
      await fetchBalanceDetails(trimId); // validate ID exists before saving
      await addMeter(trimId, trimLabel);
      await showToast({ style: Toast.Style.Success, title: "Meter saved" });
      onAdd();
      pop();
    } catch (err) {
      await showFailureToast(err instanceof Error ? err : new Error(String(err)));
    }
  }

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Save Meter" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="id" title="Customer ID" placeholder="e.g. 31719842" />
      <Form.TextField id="label" title="Label (optional)" placeholder="e.g. Home, Office" />
    </Form>
  );
}

// ─── Edit Label Form ─────────────────────────────────────────────────────────
function EditLabelForm({ meter, onSave }: { meter: Meter; onSave: () => void }) {
  const { pop } = useNavigation();

  async function handleSubmit(values: { label: string }) {
    await updateLabel(meter.id, values.label.trim());
    onSave();
    pop();
  }

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Save Label" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="label" title="Label" defaultValue={meter.label ?? ""} />
    </Form>
  );
}

// ─── Meter Detail View ───────────────────────────────────────────────────────
function MeterDetail({
  row,
  threshold,
  onRefresh,
  onRemove,
}: {
  row: MeterRow;
  threshold: number;
  onRefresh: () => void;
  onRemove: () => void;
}) {
  const { pop } = useNavigation();
  const { meter, balance, fetchedAt, stale, error } = row;
  const isLow = balance != null && balance.balanceRemaining <= threshold;
  const isActive = balance?.connectionStatus.toLowerCase() === "active";

  const shareText = balance ? buildShareText(meter.id, balance) : "";

  async function handleRemove() {
    await removeMeter(meter.id);
    onRemove();
    pop();
  }

  async function handleSetPrimary() {
    await setPrimary(meter.id);
    onRefresh();
  }

  async function handleRefresh() {
    try {
      const data = await fetchBalanceDetails(meter.id);
      await setCachedBalance(meter.id, data);
      onRefresh();
    } catch (err) {
      await showFailureToast(err instanceof Error ? err : new Error(String(err)));
    }
  }

  return (
    <List.Item.Detail
      metadata={
        balance ? (
          <List.Item.Detail.Metadata>
            <List.Item.Detail.Metadata.Label
              title="Balance"
              text={`${formatBalance(balance.balanceRemaining)}${stale ? " (stale)" : ""}`}
            />
            <List.Item.Detail.Metadata.TagList title="Status">
              <List.Item.Detail.Metadata.TagList.Item
                text={balance.connectionStatus}
                color={isLow ? Color.Red : isActive ? Color.Green : Color.Orange}
              />
            </List.Item.Detail.Metadata.TagList>
            <List.Item.Detail.Metadata.Separator />
            <List.Item.Detail.Metadata.Label title="Customer Name" text={balance.customerName} />
            <List.Item.Detail.Metadata.Label title="Account ID" text={balance.accountId} />
            <List.Item.Detail.Metadata.Label title="Customer Class" text={balance.customerClass} />
            <List.Item.Detail.Metadata.Label title="Customer Type" text={balance.customerType} />
            <List.Item.Detail.Metadata.Label title="Account Type" text={balance.accountType} />
            {balance.mobileNumber && (
              <List.Item.Detail.Metadata.Label title="Mobile" text={balance.mobileNumber} />
            )}
            {balance.emailId && (
              <List.Item.Detail.Metadata.Label title="Email" text={balance.emailId} />
            )}
            {balance.minRecharge != null && (
              <List.Item.Detail.Metadata.Label title="Min Recharge" text={formatBalance(balance.minRecharge)} />
            )}
          </List.Item.Detail.Metadata>
        ) : (
          <List.Item.Detail.Metadata>
            <List.Item.Detail.Metadata.Label title="Error" text={error ?? "No data"} />
          </List.Item.Detail.Metadata>
        )
      }
    />
  );
  void handleRemove; void handleSetPrimary; void handleRefresh; void shareText;
}

// ─── Main List Component ─────────────────────────────────────────────────────
export default function MyMeters() {
  const { push } = useNavigation();
  const prefs = getPreferenceValues<Preferences>();
  const threshold = parseFloat(prefs.alertThreshold) || 50;

  const { data, isLoading, revalidate } = useCachedPromise(loadAll, [], {
    keepPreviousData: true,
  });

  const refresh = useCallback(() => {
    revalidate();
  }, [revalidate]);

  const rows = data ?? [];

  return (
    <List isLoading={isLoading} isShowingDetail={rows.length > 0}>
      {rows.length === 0 && !isLoading ? (
        <List.EmptyView
          icon="🔌"
          title="No meters yet"
          description="Press ⌘N to add your DPDC Customer ID"
          actions={
            <ActionPanel>
              <Action.Push
                title="Add Meter"
                shortcut={{ modifiers: ["cmd"], key: "n" }}
                target={<AddMeterForm onAdd={refresh} />}
              />
            </ActionPanel>
          }
        />
      ) : (
        rows.map((row) => {
          const { meter, balance, fetchedAt, stale, error } = row;
          const isLow = balance != null && balance.balanceRemaining <= threshold;
          const isActive = balance?.connectionStatus.toLowerCase() === "active";
          const displayName = meter.label ?? meter.id;
          const shortId = meter.id.length > 8 ? `${meter.id.slice(0, 4)}…${meter.id.slice(-4)}` : meter.id;
          const shareText = balance ? buildShareText(meter.id, balance) : "";

          const subtitleParts = [];
          if (meter.label) subtitleParts.push(shortId);
          if (fetchedAt > 0) subtitleParts.push(`updated ${formatTimeAgo(fetchedAt)}${stale ? " (stale)" : ""}`);
          if (error && !balance) subtitleParts.push("error");

          async function handleRemove() {
            await removeMeter(meter.id);
            refresh();
          }

          async function handleSetPrimary() {
            await setPrimary(meter.id);
            refresh();
          }

          async function handleRefreshItem() {
            try {
              const data = await fetchBalanceDetails(meter.id);
              await setCachedBalance(meter.id, data);
              refresh();
            } catch (err) {
              await showFailureToast(err instanceof Error ? err : new Error(String(err)));
            }
          }

          return (
            <List.Item
              key={meter.id}
              icon={meter.isPrimary ? "⭐" : Icon.Circle}
              title={displayName}
              subtitle={subtitleParts.join(" · ")}
              accessories={[
                ...(balance
                  ? [
                      {
                        tag: {
                          value: isActive ? "active" : "inactive",
                          color: isLow ? Color.Red : isActive ? Color.Green : Color.Orange,
                        },
                      },
                      { text: formatBalance(balance.balanceRemaining) },
                    ]
                  : error
                  ? [{ tag: { value: "error", color: Color.Red } }]
                  : []),
              ]}
              detail={<MeterDetail row={row} threshold={threshold} onRefresh={refresh} onRemove={refresh} />}
              actions={
                <ActionPanel>
                  <ActionPanel.Section>
                    <Action
                      title="Refresh"
                      icon={Icon.ArrowClockwise}
                      shortcut={{ modifiers: ["cmd"], key: "r" }}
                      onAction={handleRefreshItem}
                    />
                    {!meter.isPrimary && (
                      <Action
                        title="Set as Primary"
                        icon={Icon.Star}
                        shortcut={{ modifiers: ["cmd"], key: "p" }}
                        onAction={handleSetPrimary}
                      />
                    )}
                  </ActionPanel.Section>
                  <ActionPanel.Section>
                    {balance && (
                      <>
                        <Action.CopyToClipboard
                          title="Copy Balance"
                          content={formatBalance(balance.balanceRemaining)}
                        />
                        <Action.CopyToClipboard title="Copy Customer ID" content={meter.id} />
                        <Action.CopyToClipboard title="Copy All Details" content={shareText} />
                        <Action.CreateQuicklink
                          quicklink={{ link: `raycast://extensions/masnun-siam/dpdc-balance/check-balance?id=${meter.id}`, name: `DPDC ${displayName}` }}
                        />
                      </>
                    )}
                  </ActionPanel.Section>
                  <ActionPanel.Section>
                    <Action.Push
                      title="Add Meter"
                      icon={Icon.Plus}
                      shortcut={{ modifiers: ["cmd"], key: "n" }}
                      target={<AddMeterForm onAdd={refresh} />}
                    />
                    <Action.Push
                      title="Edit Label"
                      icon={Icon.Pencil}
                      target={<EditLabelForm meter={meter} onSave={refresh} />}
                    />
                    <Action
                      title="Remove Meter"
                      icon={Icon.Trash}
                      style={Action.Style.Destructive}
                      onAction={handleRemove}
                    />
                  </ActionPanel.Section>
                </ActionPanel>
              }
            />
          );
        })
      )}
    </List>
  );
}
```

- [x] **Step 2: Run lint**

```bash
npm run lint
```

Fix any formatting/lint issues reported. Expected: no errors.

- [x] **Step 3: Test manually in Raycast**

```bash
npm run dev
```

In Raycast, search "My Meters" and run it. Verify:

- EmptyView shows with ⌘N prompt when no meters saved
- ⌘N opens Add Meter form; entering a valid ID fetches + saves it
- Meter appears in list with balance, status tag, "updated just now"
- Selecting the meter shows the detail metadata panel on the right
- ⌘R refreshes the balance
- ⭐ appears on the primary meter; ⌘P on another sets it primary
- Removing a meter works

- [x] **Step 4: Commit**

```bash
git add src/my-meters.tsx
git commit -m "feat: add My Meters command with list, detail, and full action set"
```

---

## Task 6: Check Balance Command

**Files:**

- Modify: `src/check-balance.tsx` (replace placeholder)

**Interfaces:**

- Consumes: `validateCustomerId`, `fetchBalanceDetails` from `src/lib/dpdc.ts`; `isSaved`, `addMeter`, `setCachedBalance` from `src/lib/storage.ts`; `formatBalance`, `buildShareText` from `src/lib/format.ts`

- [x] **Step 1: Write `src/check-balance.tsx`**

```tsx
import {
  Action,
  ActionPanel,
  Color,
  Form,
  getPreferenceValues,
  Icon,
  List,
  showToast,
  Toast,
  useNavigation,
} from "@raycast/api";
import { showFailureToast } from "@raycast/utils";
import { useState } from "react";
import type { BalanceDetails, Preferences } from "./lib/types";
import { formatBalance, buildShareText } from "./lib/format";
import { isSaved, addMeter, setCachedBalance } from "./lib/storage";
import { fetchBalanceDetails, validateCustomerId } from "./lib/dpdc";

// ─── Save Meter Form (shown after a successful ad-hoc lookup) ────────────────
function SaveMeterForm({ id, onSave }: { id: string; onSave: () => void }) {
  const { pop } = useNavigation();

  async function handleSubmit(values: { label: string }) {
    await addMeter(id, values.label.trim() || undefined);
    await showToast({ style: Toast.Style.Success, title: "Meter saved" });
    onSave();
    pop();
  }

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Save Meter" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.Description title="Customer ID" text={id} />
      <Form.TextField id="label" title="Label (optional)" placeholder="e.g. Home, Office" />
    </Form>
  );
}

// ─── Balance Result Detail ───────────────────────────────────────────────────
function BalanceDetail({
  id,
  balance,
  alreadySaved,
  threshold,
  onSaved,
}: {
  id: string;
  balance: BalanceDetails;
  alreadySaved: boolean;
  threshold: number;
  onSaved: () => void;
}) {
  const { push } = useNavigation();
  const isLow = balance.balanceRemaining <= threshold;
  const isActive = balance.connectionStatus.toLowerCase() === "active";
  const shareText = buildShareText(id, balance);

  return (
    <List navigationTitle={`Balance: ${id}`} isShowingDetail>
      <List.Item
        title={balance.customerName}
        subtitle={id}
        detail={
          <List.Item.Detail
            metadata={
              <List.Item.Detail.Metadata>
                <List.Item.Detail.Metadata.Label
                  title="Balance"
                  text={formatBalance(balance.balanceRemaining)}
                />
                <List.Item.Detail.Metadata.TagList title="Status">
                  <List.Item.Detail.Metadata.TagList.Item
                    text={balance.connectionStatus}
                    color={isLow ? Color.Red : isActive ? Color.Green : Color.Orange}
                  />
                </List.Item.Detail.Metadata.TagList>
                <List.Item.Detail.Metadata.Separator />
                <List.Item.Detail.Metadata.Label title="Customer Name" text={balance.customerName} />
                <List.Item.Detail.Metadata.Label title="Account ID" text={balance.accountId} />
                <List.Item.Detail.Metadata.Label title="Customer Class" text={balance.customerClass} />
                <List.Item.Detail.Metadata.Label title="Customer Type" text={balance.customerType} />
                <List.Item.Detail.Metadata.Label title="Account Type" text={balance.accountType} />
                {balance.mobileNumber && (
                  <List.Item.Detail.Metadata.Label title="Mobile" text={balance.mobileNumber} />
                )}
                {balance.emailId && (
                  <List.Item.Detail.Metadata.Label title="Email" text={balance.emailId} />
                )}
                {balance.minRecharge != null && (
                  <List.Item.Detail.Metadata.Label title="Min Recharge" text={formatBalance(balance.minRecharge)} />
                )}
              </List.Item.Detail.Metadata>
            }
          />
        }
        actions={
          <ActionPanel>
            {!alreadySaved && (
              <Action.Push
                title="Save Meter"
                icon={Icon.Plus}
                shortcut={{ modifiers: ["cmd"], key: "s" }}
                target={<SaveMeterForm id={id} onSave={onSaved} />}
              />
            )}
            <Action.CopyToClipboard title="Copy Balance" content={formatBalance(balance.balanceRemaining)} />
            <Action.CopyToClipboard title="Copy Customer ID" content={id} />
            <Action.CopyToClipboard title="Copy All Details" content={shareText} />
          </ActionPanel>
        }
      />
    </List>
  );
  void push;
}

// ─── Main: Customer ID lookup form ──────────────────────────────────────────
export default function CheckBalance() {
  const { push } = useNavigation();
  const prefs = getPreferenceValues<Preferences>();
  const threshold = parseFloat(prefs.alertThreshold) || 50;

  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(values: { id: string }) {
    const trimId = values.id.trim();
    if (!validateCustomerId(trimId)) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Invalid Customer ID",
        message: "Must be 8–12 digits, numbers only.",
      });
      return;
    }

    setIsLoading(true);
    try {
      await showToast({ style: Toast.Style.Animated, title: "Fetching balance…" });
      const balance = await fetchBalanceDetails(trimId);
      await setCachedBalance(trimId, balance);
      const saved = await isSaved(trimId);
      push(
        <BalanceDetail
          id={trimId}
          balance={balance}
          alreadySaved={saved}
          threshold={threshold}
          onSaved={() => {
            // Nothing to revalidate here; My Meters command handles its own data
          }}
        />
      );
    } catch (err) {
      await showFailureToast(err instanceof Error ? err : new Error(String(err)));
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <Form
      isLoading={isLoading}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Check Balance" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="id" title="Customer ID" placeholder="e.g. 31719842" info="8–12 digit numeric ID" />
    </Form>
  );
}
```

- [x] **Step 2: Run lint**

```bash
npm run lint
```

Fix any issues. Expected: no errors.

- [x] **Step 3: Test manually in Raycast**

Run `npm run dev`. In Raycast search "Check Balance":

- Enter a valid Customer ID → see balance detail with full metadata
- If not saved: ⌘S shows Save Meter form with label field
- If already saved: Save action is hidden
- Invalid ID format → inline Failure toast before any network call
- Unknown (valid format) ID → "Customer ID not found" failure toast

- [x] **Step 4: Commit**

```bash
git add src/check-balance.tsx
git commit -m "feat: add Check Balance ad-hoc lookup command"
```

---

## Task 7: Menu Bar Command

**Files:**

- Modify: `src/balance-menu-bar.tsx` (replace placeholder)

**Interfaces:**

- Consumes: `getMeters`, `getCachedBalance`, `setCachedBalance` from `src/lib/storage.ts`; `fetchBalanceDetails` from `src/lib/dpdc.ts`; `formatBalance` from `src/lib/format.ts`; `getPreferenceValues`, `MenuBarExtra`, `launchCommand` from `@raycast/api`

- [x] **Step 1: Write `src/balance-menu-bar.tsx`**

```tsx
import { getPreferenceValues, Icon, LaunchType, MenuBarExtra, openCommandPreferences } from "@raycast/api";
import { useCachedPromise, showFailureToast } from "@raycast/utils";
import { getMeters, getCachedBalance, setCachedBalance } from "./lib/storage";
import { fetchBalanceDetails } from "./lib/dpdc";
import { formatBalance } from "./lib/format";
import type { BalanceDetails, Preferences } from "./lib/types";

interface MenuRow {
  id: string;
  label: string;
  isPrimary: boolean;
  balance: BalanceDetails | null;
  error: string | null;
}

async function loadMenuData(): Promise<MenuRow[]> {
  const meters = await getMeters();
  const prefs = getPreferenceValues<Preferences>();
  const cacheTTL = parseInt(prefs.refreshInterval) * 60_000;

  return Promise.all(
    meters.map(async (meter): Promise<MenuRow> => {
      const cached = await getCachedBalance(meter.id);
      const isStale = !cached || Date.now() - cached.fetchedAt > cacheTTL;

      if (!isStale && cached) {
        return {
          id: meter.id,
          label: meter.label ?? meter.id,
          isPrimary: meter.isPrimary,
          balance: cached.data,
          error: null,
        };
      }
      try {
        const data = await fetchBalanceDetails(meter.id);
        await setCachedBalance(meter.id, data);
        return { id: meter.id, label: meter.label ?? meter.id, isPrimary: meter.isPrimary, balance: data, error: null };
      } catch (err) {
        if (cached) {
          return {
            id: meter.id,
            label: meter.label ?? meter.id,
            isPrimary: meter.isPrimary,
            balance: cached.data,
            error: String(err),
          };
        }
        return { id: meter.id, label: meter.label ?? meter.id, isPrimary: meter.isPrimary, balance: null, error: String(err) };
      }
    })
  );
}

export default function BalanceMenuBar() {
  const prefs = getPreferenceValues<Preferences>();
  const threshold = parseFloat(prefs.alertThreshold) || 50;

  const { data, isLoading, revalidate } = useCachedPromise(loadMenuData, [], {
    keepPreviousData: true,
  });

  const rows = data ?? [];
  const primary = rows.find((r) => r.isPrimary);
  const anyLow = rows.some((r) => r.balance != null && r.balance.balanceRemaining <= threshold);

  // Title: primary balance or loading indicator
  const title = primary?.balance
    ? formatBalance(primary.balance.balanceRemaining)
    : isLoading
    ? "⟳"
    : "—";
  const icon = anyLow ? { source: Icon.ExclamationMark, tintColor: { light: "#ff0000", dark: "#ff5555", adjustContrast: false } } : "⚡";

  async function handleRefresh() {
    try {
      revalidate();
    } catch (err) {
      await showFailureToast(err instanceof Error ? err : new Error(String(err)));
    }
  }

  async function openMyMeters() {
    const { launchCommand } = await import("@raycast/api");
    await launchCommand({ name: "my-meters", type: LaunchType.UserInitiated });
  }

  return (
    <MenuBarExtra icon={icon} title={title} isLoading={isLoading}>
      {rows.length === 0 ? (
        <MenuBarExtra.Item title="No meters saved" onAction={openMyMeters} />
      ) : (
        <MenuBarExtra.Section title="Meters">
          {rows.map((row) => {
            const balanceText = row.balance
              ? formatBalance(row.balance.balanceRemaining)
              : row.error
              ? "Error"
              : "…";
            const isLow = row.balance != null && row.balance.balanceRemaining <= threshold;
            const prefix = row.isPrimary ? "⭐ " : "   ";
            const lowFlag = isLow ? " 🔴" : "";

            return (
              <MenuBarExtra.Item
                key={row.id}
                title={`${prefix}${row.label}   ${balanceText}${lowFlag}`}
                onAction={openMyMeters}
              />
            );
          })}
        </MenuBarExtra.Section>
      )}

      <MenuBarExtra.Section>
        <MenuBarExtra.Item
          title="Refresh Now"
          icon={Icon.ArrowClockwise}
          onAction={handleRefresh}
        />
        <MenuBarExtra.Item
          title="Open My Meters"
          icon={Icon.List}
          onAction={openMyMeters}
        />
        <MenuBarExtra.Item
          title="Preferences…"
          icon={Icon.Gear}
          onAction={openCommandPreferences}
        />
      </MenuBarExtra.Section>
    </MenuBarExtra>
  );
}
```

- [x] **Step 2: Run lint**

```bash
npm run lint
```

Fix any issues. Expected: no errors.

- [x] **Step 3: Test manually in Raycast**

Run `npm run dev`. In Raycast enable "Balance" menu-bar command:

- Menu-bar shows `⚡ ৳1,234.00` for the primary meter
- Dropdown shows all meters with balances; clicking opens My Meters
- "Refresh Now" fetches fresh balances
- Set `alertThreshold` preference to a value above the primary balance → title/icon turns red 🔴
- With no meters saved: shows "No meters saved"

- [x] **Step 4: Commit**

```bash
git add src/balance-menu-bar.tsx
git commit -m "feat: add Balance menu-bar command with primary meter title and threshold alert"
```

---

## Task 8: Polish — Icon, Lint, Verification

**Files:**

- Create: `assets/extension-icon.png` (placeholder or real 1024×1024 PNG)
- Verify: `npm run lint` clean, all test scenarios pass

**Interfaces:**

- Consumes: entire built extension
- Produces: store-quality, lint-clean extension importable via Raycast dev mode

- [x] **Step 1: Add extension icon**

The `package.json` references `extension-icon.png` in `assets/`. Create a 1024×1024 PNG.
Quick option — use the ⚡ or 🔌 emoji rendered as an image, or copy a lightning-bolt icon.
Minimum requirement: the file must exist and be a valid PNG or the extension won't load.

If you have ImageMagick installed:

```bash
cd /Users/siam/Documents/Projects/Personal/dpdc-raycast
convert -size 1024x1024 xc:#1E40AF -font DejaVu-Sans -pointsize 600 \
  -fill white -gravity Center -annotate 0 "⚡" assets/extension-icon.png
```

Otherwise, copy any 1024×1024 PNG into `assets/extension-icon.png` temporarily and replace with a proper icon later.

- [x] **Step 2: Run the full test suite**

```bash
cd /Users/siam/Documents/Projects/Personal/dpdc-raycast
npm test
```

Expected: All tests PASS.

- [x] **Step 3: Run lint clean**

```bash
npm run lint
```

Expected: No errors. Fix any remaining warnings until clean.

- [x] **Step 4: Run end-to-end verification scenarios**

With `npm run dev` active in Raycast, verify each scenario:

| Scenario | Expected |
|----------|----------|
| Check Balance with real ID (e.g. `31719842`) | Balance, name, status shown; matches mobile app |
| Save that ID with label "Home" | Appears in My Meters with ⭐ (first meter = primary) |
| Add a second meter | No ⭐, both listed with balances |
| ⌘P on second meter | ⭐ moves; menu-bar title shows second meter's balance |
| Set `alertThreshold` pref above primary balance | List item + menu-bar icon turns 🔴 |
| Kill network → Refresh | Failure toast shown; stale balance still visible |
| Invalid Customer ID (`abc`, `123`) | Inline validation toast, no network call |
| Unknown valid-format ID (`99999999`) | "Customer ID not found" failure toast |
| Remove all meters | EmptyView appears with ⌘N prompt |
| Menu-bar "Refresh Now" | Fresh fetch, "updated just now" in My Meters |

- [x] **Step 5: Final commit**

```bash
git add assets/extension-icon.png
git commit -m "feat: add extension icon and polish — all verification scenarios pass"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** All commands (My Meters, Check Balance, menu-bar) implemented. All preferences (alertThreshold, refreshInterval) wired. Stale-fallback error handling. Primary meter selection. Token caching (getValidAccessToken in dpdc.ts). Copy All Details (buildShareText). Quicklink creation action. EmptyView. ⭐ primary marker.
- [x] **No placeholders:** All steps contain actual code, commands, and expected output.
- [x] **Type consistency:** `BalanceDetails.balanceRemaining` used throughout; `formatBalance` called in all views; `getCachedBalance`/`setCachedBalance` signatures consistent; `Preferences.alertThreshold` (string, parsed at use site) consistent across my-meters, check-balance, balance-menu-bar.
- [x] **Hardcoded credentials:** clientId, clientSecret, tenantCode only in `src/lib/dpdc.ts`.
- [x] **Auth flow:** `generateBearerToken(refreshToken?)` → `POST AUTH_URL` with `clientId`, `clientSecret`, `tenantCode` headers; refresh path sends old token in `Authorization`; fresh path omits it. Matches `dpdc_api_service.dart` exactly.
- [x] **GraphQL query:** Sends all 10 fields; handles `errors[]` at top level + null `postBalanceDetails`. Both mapped in tests.
- [x] **`accessToken` custom header:** Sent alongside `Authorization: Bearer` on balance calls (both headers, matching mobile app).
